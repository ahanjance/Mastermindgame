import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Data Models
struct CreateGameResponse: Codable {
    let game_id: String
}

struct GuessRequest: Codable {
    let game_id: String
    let guess: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Network Errors (FIXED)
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case apiError(String)
    case gameNotFound
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .apiError(let message):
            return "API Error: \(message)"
        case .gameNotFound:
            return "Game not found"
        case .serverError:
            return "Server error"
        }
    }
}

// MARK: - API Manager
class MastermindAPIManager {
    private let baseURL = "https://mastermind.darkube.app"
    private let session = URLSession.shared
    
    func createGame(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let gameResponse = try JSONDecoder().decode(CreateGameResponse.self, from: data)
                completion(.success(gameResponse.game_id))
            } catch {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NetworkError.apiError(errorResponse.error)))
                } else {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func makeGuess(gameId: String, guess: String, completion: @escaping (Result<GuessResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/guess") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let guessRequest = GuessRequest(game_id: gameId, guess: guess)
        
        do {
            let jsonData = try JSONEncoder().encode(guessRequest)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let guessResponse = try JSONDecoder().decode(GuessResponse.self, from: data)
                completion(.success(guessResponse))
            } catch {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NetworkError.apiError(errorResponse.error)))
                } else {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func deleteGame(gameId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game/\(gameId)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    completion(.success(()))
                } else if httpResponse.statusCode == 404 {
                    completion(.failure(NetworkError.gameNotFound))
                } else {
                    completion(.failure(NetworkError.serverError))
                }
            }
        }
        
        task.resume()
    }
}

// MARK: - Game Logic
class MastermindGame {
    private let apiManager = MastermindAPIManager()
    private var gameId: String?
    private var attempts: Int = 0
    private let maxAttempts: Int = 10
    private let semaphore = DispatchSemaphore(value: 0)
    
    private func validateInput(_ input: String) -> Bool {
        guard input.count == 4 else {
            print("❌ Code must be exactly 4 digits")
            return false
        }
        
        for char in input {
            guard let digit = Int(String(char)), digit >= 1 && digit <= 6 else {
                print("❌ Each digit must be between 1 and 6")
                return false
            }
        }
        
        return true
    }
    
    private func formatFeedback(blacks: Int, whites: Int) -> String {
        var feedback = ""
        feedback += String(repeating: "B", count: blacks)
        feedback += String(repeating: "W", count: whites)
        return feedback.isEmpty ? "None" : feedback
    }
    
    private func displayGameState() {
        print("\n" + String(repeating: "=", count: 40))
        print("🎯 Mastermind Game (Online)")
        print("🆔 Game ID: \(gameId ?? "N/A")")
        print("📊 Attempt: \(attempts)/\(maxAttempts)")
        print("💡 Guide: B = Correct position, W = Correct digit wrong position")
        print("⌨️  Type 'exit' to quit")
        print(String(repeating: "=", count: 40))
    }
    
    private func createNewGame() -> Bool {
        print("🔄 Creating new game...")
        
        var success = false
        apiManager.createGame { [weak self] result in
            switch result {
            case .success(let gameId):
                self?.gameId = gameId
                print("✅ Game created successfully! Game ID: \(gameId)")
                success = true
            case .failure(let error):
                print("❌ Failed to create game: \(error.localizedDescription)")
                success = false
            }
            self?.semaphore.signal()
        }
        
        semaphore.wait()
        return success
    }
    
    private func makeGuess(_ guess: String) -> GuessResponse? {
        guard let gameId = gameId else {
            print("❌ No active game")
            return nil
        }
        
        print("🔄 Sending guess to server...")
        
        var result: GuessResponse?
        apiManager.makeGuess(gameId: gameId, guess: guess) { [weak self] response in
            switch response {
            case .success(let guessResponse):
                result = guessResponse
            case .failure(let error):
                print("❌ Failed to make guess: \(error.localizedDescription)")
                result = nil
            }
            self?.semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    private func deleteGame() {
        guard let gameId = gameId else { return }
        
        apiManager.deleteGame(gameId: gameId) { [weak self] result in
            switch result {
            case .success:
                print("🗑️ Game deleted successfully")
            case .failure(let error):
                print("⚠️ Failed to delete game: \(error.localizedDescription)")
            }
            self?.semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    func startGame() {
        print("🎮 Welcome to Online Mastermind Game!")
        print("🌐 Using API: https://mastermind.darkube.app")
        print("🎯 The server will generate a secret 4-digit code (numbers 1-6)")
        print("🎪 You have \(maxAttempts) attempts to guess it")
        
        // Create new game
        guard createNewGame() else {
            print("💔 Cannot start game without server connection")
            return
        }
        
        while attempts < maxAttempts {
            displayGameState()
            
            print("\n🤔 Enter your guess (example: 1234): ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }
            
            // Check for exit
            if input.lowercased() == "exit" {
                print("👋 Goodbye!")
                deleteGame()
                return
            }
            
            // Validate input
            guard validateInput(input) else {
                continue
            }
            
            // Make guess via API
            guard let response = makeGuess(input) else {
                print("❌ Failed to process guess. Try again.")
                continue
            }
            
            attempts += 1
            let feedback = formatFeedback(blacks: response.black, whites: response.white)
            
            // Display result
            print("\n📋 Your guess: \(input)")
            print("📈 Result: \(feedback)")
            print("📊 Server response: \(response.black) blacks, \(response.white) whites")
            
            // Check for win
            if response.black == 4 {
                print("\n🎉🎉🎉 Congratulations! You won! 🎉🎉🎉")
                print("⚡ Number of attempts: \(attempts)")
                deleteGame()
                return
            }
            
            // Display remaining attempts
            let remaining = maxAttempts - attempts
            if remaining > 0 {
                print("⏳ \(remaining) attempts remaining")
            }
        }
        
        // Game over - loss
        print("\n💔 Unfortunately, you lost!")
        print("🔄 To play again, restart the program")
        deleteGame()
    }
}

// MARK: - Game Manager
class GameManager {
    func run() {
        var playAgain = true
        
        while playAgain {
            let game = MastermindGame()
            game.startGame()
            
            print("\n🔄 Would you like to play again? (y/n): ", terminator: "")
            if let response = readLine()?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
                playAgain = (response == "y" || response == "yes")
            } else {
                playAgain = false
            }
        }
        
        print("👋 Thank you for playing!")
    }
}

// MARK: - Program Entry Point
let gameManager = GameManager()
gameManager.run()
