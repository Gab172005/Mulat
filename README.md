# Mulat - The Boys
Gab Kalugdan - Fullstack Developer

Frendzo Charles Pelagio - Fullstack Developer

Desmond Rainier Perez - Fullstack Developer

### Project Case: Ai-Powered Study Companion For Filipino Learners

Mulat is a webapp that aims to create study aids like flashcards and micro-quizzes using AI, running client-side and functioning entirely offline once first initialized.

# Setup Instructions

## 1. Clone the Repository:
* Open your system terminal and clone the project workspace:
```
git clone https://github.com/Gab172005/Mulat.git
cd gabay-ai
```

## 2. Compile the Local AI Model:
* Navigate to the model configurations directory and build your custom localized model utilizing the provided configuration parameters:
```
cd assets/models
ollama create kabalikat -f Modelfile.kabalikat
```
## 3. Install Frontend Dependencies:
* Navigate back to your project root folder and pull all the framework dependencies required by the mobile application
```
../.. flutter pub get
```

## 4. Build and Run the Application:
* Verify deployment configurations and boot up the application directly onto your connected physical device or target emulator:
```
flutter run
```
# Developed Features

### Frontend implementation of the following: 
* Interactive Micro-Quizzes: Practice tests with correct and wrong feedback indicators, along with detailed bilingual explanations, percentage of correct and wrong, along with ability to retake and generate a new set of quizzes.
* Multi-Format Document Ingestion
* Interactive 3D Flashcards: Responsive 3D flipping card elements displaying terms on the front and definitions on the back, complete with keyboard controls and progress meters.

## AI Tools Used
* Gemini Antigravity
* Claude
