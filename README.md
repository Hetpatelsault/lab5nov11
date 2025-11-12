# Pokémon Battle of HP

A fun **Flutter application** where two random Pokémon cards are drawn from an online API to battle based on their **HP (Health Points)**.  
Each round displays two cards, compares their HP, and declares a **winner**, **loser**, or **draw**.

If the online Pokémon API fails to load, the app automatically uses a **local fallback dataset** to ensure it always works — even offline.

##  Features

 Fetches two random Pokémon cards from the official Pokémon TCG API  
 Calculates and displays HP for both cards  
 Declares the winner based on HP comparison  
 “Draw Again” button to refresh the battle  
 Graceful fallback to local JSON data if the API is unavailable  
 Displays loading and error states clearly  
 Clean and minimal Material 3 UI  

##  Tech Stack

- **Language:** Dart  
- **Framework:** Flutter  
- **Packages Used:**
  - `http` – For API requests
*i use ai to get the idea and also use it to solve the error in code.*
*I use gpt to design the best layout for the project*

**Primary API (Online)**  

