# P. I. M. P v0.01

Hello! This is my project in which I am building a (name may change) Programmable Instrument for Multi-Modal Performance, or PIMP for short.

This uses SuperCollider for audio synthesis, Processing4 for the visuals, Arduino for control input, and then Python as a communicator between everything.

## SuperCollider Portion

--- Needs Much Development ---

Ideas I have for pieces/types of music I want to be able to produce:
-> Breakcore/EDM
-> Ambient/Evolving
-> Pattern Based Algorithmic Music
    -> If I can figure out a way to do presets have a classical inspired preset?
-> Industrial
-> Esoteric Soundscapes

I'm essentially wanting to be able to make all the kinds of music I've been itching to make, but felt like I didn't have
the proper creative outlet to make them.

## Processing Portion

I'm Imagining to have 3 Different Sketches that I'll need to figure out how to switch between from the Arduino, but thats a later bridge!

1. Spellsinger Mode

This is more of a fun gimmic I wanted to do, certain samples will cast certain spells
-> Hats trigger Fireballs
-> Kicks trigger Thunderbolts

-> (NI) Magic Missiles for various glitch sounds?

I'm wanting this to be very fun with making breakcore type music.

2. (NI) Audio Reactive Multitude

-> This processing sketch would have multiple modes within itself

I'm thinking one minimal with a simple frequency reaction, one dreamy/vhs/colorful one, and a third.

3. -- NO CONCRETE IDEA YET --

## Data and Communication

Python is the controlling brain in this, not so much the arduino. Python is what reads the arduino data and then creates and sends OSC data based on that. 

I have a feeling that this is where I will see the main bottleneck for getting this to keep expanding. Trying to figure out the logic and button mapping in
python to get from the Arduino input to my desired output.


## Hardware and Control Points

Right now, one button that triggers a synth and makes a fireball

Also, each server itself is technically a control point. Processing can talk to SuperCollider, SuperCollider can talk to Processing, SuperCollider can read Arduino, 
vice versa, so on and so forth.

I really enjoy this part of the idea as it can lead to so many extensions to it!

## Known Issues and Hopes for the Future

It is still in a very primitive state. But I hope for this to be able to be capable of interesting real time performances as well as being able to mess around and record in a studio environment. 

I already know I will have to upgrade the hardware, and I'm leaning towards a Raspberry Pi 5 and a Teensy 4.1 (or is 5.1 the newest?) to replace my Pi 3B and Arduino Uno.

This will be able to adopt interaction with new data types and communication types relatively easily and with it being written in these highly extended languages, there is truly going to be so many directions this can go.

### Wanted Implementations
-> Anything above labeled (NI)
-> DMX Automation Capabilities (Far Future, perhaps 2.0 or 3.0)
-> Midi Capabilities