// spellbook.scd
s = Server.local;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

(
// Wait for all previous code to complete
s.waitForBoot({
    //Server.killAll; // Clears everything if rebooting..
    OSCdef.freeAll; // Clear any previous OSC defs to avoid duplicates

    "Booting audio synthesis server...".postln;

    // Wait for SynthDefs to be added
    Server.default.sync;
    s.meter;
    s.plotTree;

    // load Synths and Patterns
    "synthdefs.scd".standardizePath.load;
    " - SynthDefs loaded".postln;

    "patterns.scd".standardizePath.load;
    " - Patterns loaded".postln;

    // Global variables for pattern control
    ~currentPattern = nil;
    ~normalWavePatterns = Array.newClear(5);
    ~bossPattern = nil;
    
    // Define the tempo
    TempoClock.default.tempo = 120/60;

    // Normal wave background patterns (dreamy, easy-going)
    ~normalWavePatterns[0] = Pbind(
        \instrument, \chimes,
        \dur, Pseq([2, 2, 1, 1], inf),
        \note, Pseq([0, 4, 7, 11], inf),
        \octave, 5,
        \amp, 0.3
    );

    ~normalWavePatterns[1] = Pbind(
        \instrument, \sawPad,
        \dur, Pseq([4], inf),
        \note, Prand([
            Pseq([0, 4, 7]),
            Pseq([2, 5, 9]),
            Pseq([-1, 2, 7])
        ], inf),
        \amp, 0.2
    );

    // Basic drum pattern
    ~drumPattern = Pbind(
        \instrument, Prand([\kick, \hihat, \snare, \clap], inf),
        \dur, Pseq([1, 0.5, 0.5, 1], inf),
        \amp, 0.4
    );

    // Boss wave pattern (more aggressive)
    ~bossPattern = Pbind(
        \instrument, \distSaw,
        \dur, Pseq([0.25, 0.25, 0.5], inf),
        \note, Pseq([0, 4, 7, 11, 14, 11, 7, 4], inf),
        \amp, 0.3
    );

    // OSC handlers for wave control
    OSCdef(\waveNormalStart, {|msg, time, addr, recvPort|
        var waveNum = msg[1];
        ~currentPattern.stop;
        ~currentPattern = Ppar([
            ~normalWavePatterns[waveNum % 2],
            ~drumPattern
        ]).play;
    }, '/wave/normal/start');

    OSCdef(\waveBossStart, {|msg, time, addr, recvPort|
        ~currentPattern.stop;
        ~currentPattern = Ppar([
            ~bossPattern,
            ~drumPattern
        ]).play;
    }, '/wave/boss/start');

    OSCdef(\waveEnd, {|msg, time, addr, recvPort|
        if(~currentPattern.notNil, {
            ~currentPattern.stop;
        });
    }, '/wave/end');

    // Existing OSC handlers
    OSCdef(\sine_t, {|msg, time, addr, recvPort|
        Synth(\sine, [
            \freq, rrand(440, 880),
            \pan, rrand(-0.7, 0.7),
        ]);
    }, '/sine_t');

    OSCdef(\kick_test, {|msg, time, addr, recvPort|
        Synth(\kick);
    }, '/kick');

    // Enemy death sounds
    OSCdef(\goblinDeath, {|msg, time, addr, recvPort|
        Synth(\goblinDeath, [\amp, 0.3]);
    }, '/flying-goblin/death');

    OSCdef(\batDeath, {|msg, time, addr, recvPort|
        Synth(\batDeath, [\amp, 0.3]);
    }, '/bat-swarm/death');

    OSCdef(\dragonDeath, {|msg, time, addr, recvPort|
        Synth(\dragonDeath, [\amp, 0.5]);
    }, '/red-dragon/death');

    " - OSCdefs initialized".postln;
    " -- SuperCollider Ready! --".postln;
});
)