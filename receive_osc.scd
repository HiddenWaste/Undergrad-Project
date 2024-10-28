// osc_project.scd
(
// Wait for all previous code to complete
s.waitForBoot({
    "Booting server...".postln;

    // Clear any previous OSC defs to avoid duplicates
    OSCdef.freeAll;

    // Define the synth
    SynthDef(\simpleSynth, {
        arg freq=440;
        var sig = SinOsc.ar(freq) * EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2);
        Out.ar(0, sig * 0.5);
    }).add;

    // Wait for SynthDef to be added
    Server.default.sync;

    // Set up OSC listener
    OSCdef(\triggerResponder, {|msg, time, addr, recvPort|
        "Received trigger".postln;
        Synth(\simpleSynth, [\freq, rrand(440, 880)]);
    }, '/trigger');

    "Project ready:".postln;
    " - SynthDef loaded".postln;
    " - OSC responder ready on /trigger".postln;
    "You can now run the Python script".postln;
});
)

// Optional: To stop the project, evaluate this block:
/*
(
OSCdef(\triggerResponder).free;
"OSC responder stopped.".postln;
)
*/