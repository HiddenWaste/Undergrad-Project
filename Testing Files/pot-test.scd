// Start the server
Server.default.boot;

// First create a reverb bus and synth
(
// Create a bus for the reverb
~reverbBus = Bus.audio(Server.default, 2);

// Create a reverb synth
SynthDef(\reverb, {
    arg in=0, roomsize=0.5, damping=0.5, mix=0.3;
    var sig, wet;
    sig = In.ar(in, 2);
    wet = FreeVerb2.ar(sig[0], sig[1],
        mix: mix,
        room: roomsize,
        damp: damping
    );
    Out.ar(0, wet);
}).add;
)

// Create a SynthDef for the main synth
(
SynthDef(\controlledSynth, {
    arg freq=440, vol=50, out=0;
    var sig;

    // Create a basic synth with controllable frequency
    sig = SinOsc.ar(freq) * (vol/100);

    Out.ar(out, sig ! 2);  // Output to specified bus
}).add;
)

// Create the synths in the right order
(
~reverbSynth = Synth.tail(nil, \reverb, [\in, ~reverbBus]);
~synth = Synth.head(nil, \controlledSynth, [\out, ~reverbBus]);
)

// OSC listeners
(
OSCdef(\volumeControl, {|msg|
    ~synth.set(\vol, msg[1]);
}, '/pot/volume');

OSCdef(\freqControl, {|msg|
    ~synth.set(\freq, msg[1]);
}, '/pot/freq');

OSCdef(\paramControl, {|msg|
    ~reverbSynth.set(\roomsize, msg[1]);
}, '/pot/param');
)