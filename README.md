# P. A. C. E v0.1

## Introduciton

Hello! This is my capstone project: a Prototyping System for Audiovisual Creative Endeavors (P.A.C.E)

This system uses a Teensy 4.1 controller to read input and print it as serial data.

Python then reads the serial data and interprets it according to the config file, and thenwill send the needed information to either SuperCollider or Processing4.

This uses SuperCollider scripts for audio synthesis / playback, and Processing4 for this visual elements.

Currently there are 3 modes that work.

# Working Modes

## main-menu

This is an idling screen I've implemented to have playing while I am not actively showcasing the project. It's a very relatively simple mode.

The name of the project is in the center of a sea of magenta and teal, all with VHS filters. SuperCollider plays through a file of Steve Reich's Music for 18 Musicians: Pulses. Supercollider then performs audio feature extraction to get the frequency centroid and sends that to processing via OSC.

The higher the centroid the more magenta, the less the more teal!.


## wizardcore

This has for the entirety of the project been my main mode when working on new hardware implementations.

A musical game where you control a wizard and have to cast spells to defeat waves of enemies. 

Enemies and game mechanics handled by processing, and control commands are usually paired with audio commands as well, such as each spell having its own sound effect.

## build-a-synth-workshop


# Future Modes

## Glassian Autonomous System (G.A.S.)