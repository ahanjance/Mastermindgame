# Mastermindgame
🎯 **Swift Terminal Mastermind with API Integration**

A command-line implementation of the classic Mastermind code-breaking game built in Swift, featuring integration with a remote REST API server. Players attempt to guess a secret 4-digit code (digits 1-6) within 10 attempts, receiving feedback in the form of black pegs (correct digit in correct position) and white pegs (correct digit in wrong position).

## Key Features
- 🌐 **API Integration**: Connects to remote Mastermind server (mastermind.darkube.app)
- 🚀 **Swift Implementation**: Pure Swift code for cross-platform compatibility  
- 🎮 **Interactive Terminal UI**: Clean, emoji-enhanced user interface
- 🔄 **Game State Management**: Automatic game creation and cleanup via REST API
- ⚡ **Error Handling**: Robust network error handling and input validation
- 🎯 **Real-time Feedback**: Live communication with server for game logic

## Tech Stack
- **Language**: Swift
- **Networking**: URLSession with async/await pattern
- **API**: RESTful endpoints (POST /game, POST /guess, DELETE /game/{id})
- **Data Format**: JSON serialization/deserialization

Perfect for learning Swift networking, API integration, or as a foundation for terminal-based games. Compatible with macOS, Linux, and Windows (with Swift toolchain).
