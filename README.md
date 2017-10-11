# Researchers_Night_Game

Simple game as a showcase for Researchers' night (noc vedcu).
Implemented for TinyOS in NesC, tested on TelosB platform.

Game expects 5 static nodes, with IDs 1-5, which broadcast hello packets with ID. 
Unlimited number of receiving nodes with ID 0 can be deployed, these listen 
for messages and if received message RSSI is larger than set treshold, then displays 
single character, using Morse code and LEDs. This character is unique per node ID.  


Created by Martin Stehlik, uploaded and tested by Lukas Nemec 
