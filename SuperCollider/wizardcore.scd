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

	// Global variables for pattern control
    ~currentPattern = nil;
    ~normalWavePatterns = Array.newClear(5);
    ~bossPattern = nil;
    
    // Define the tempo
    TempoClock.default.tempo = 120/60;

    // load Synths and Patterns
    "wizard-synthdefs.scd".standardizePath.load;
    " - SynthDefs loaded".postln;

    "wizard-patterns.scd".standardizePath.load;
    " - Patterns loaded".postln;
    

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

    // OSCDef for clap synth
    OSCdef(\clap, {|msg, time, addr, recvPort|
        Synth(\clap);
    }, '/clap');

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