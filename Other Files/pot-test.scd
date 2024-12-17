(
s.waitForBoot({
    "Server booted, initializing synths...".postln;
    
    // Create a bus for the reverb
    ~reverbBus = Bus.audio(Server.default, 2);
    ~tempoClock = TempoClock.new(2); // Default 120 BPM
    ~currentSynth = 0;
    ~isGlobalMode = false;
    ~synths = [\sineSynth, \fmSynth, \pwmSynth];

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

    // Basic sine oscillator
    SynthDef(\sineSynth, {
        arg freq=440, vol=50, detune=0.1, out=0;
        var sig;
        sig = SinOsc.ar([freq, freq * (1 + detune)]) * (vol/100);
        Out.ar(out, sig);
    }).add;

    // FM synthesis
    SynthDef(\fmSynth, {
        arg freq=440, vol=50, modIndex=1, out=0;
        var carrier, modulator, sig;
        modulator = SinOsc.ar(freq * 2) * freq * modIndex;
        carrier = SinOsc.ar(freq + modulator) * (vol/100);
        Out.ar(out, carrier ! 2);
    }).add;

    // PWM synthesis
    SynthDef(\pwmSynth, {
        arg freq=440, vol=50, width=0.5, out=0;
        var sig;
        sig = Pulse.ar(freq, width) * (vol/100);
        Out.ar(out, sig ! 2);
    }).add;

    s.sync; // Wait for SynthDefs to be loaded

    // Create synths
    ~reverbSynth = Synth.tail(nil, \reverb, [\in, ~reverbBus]);
    ~sineSynth = Synth.head(nil, \sineSynth, [\out, ~reverbBus]);
    ~fmSynth = Synth.head(nil, \fmSynth, [\out, ~reverbBus]);
    ~pwmSynth = Synth.head(nil, \pwmSynth, [\out, ~reverbBus]);

    // Set initial volumes to 0
    ~sineSynth.set(\vol, 0);
    ~fmSynth.set(\vol, 0);
    ~pwmSynth.set(\vol, 0);

    // Default to sine
    ~sineSynth.set(\vol, 50);

    // OSC responders
    OSCdef.freeAll; // Clear any existing OSC definitions

    OSCdef(\synthSelect, {|msg|
        var direction = msg[1].asInteger;  // Ensure integer

        // Mute current synth
        switch(~currentSynth,
            0, { ~sineSynth.set(\vol, 0) },
            1, { ~fmSynth.set(\vol, 0) },
            2, { ~pwmSynth.set(\vol, 0) }
        );

        // Update synth selection
        ~currentSynth = (~currentSynth + direction) % 3;
        if(~currentSynth < 0, { ~currentSynth = 2 });

        // Restore volume to selected synth
        switch(~currentSynth,
            0, { ~sineSynth.set(\vol, 50) },
            1, { ~fmSynth.set(\vol, 50) },
            2, { ~pwmSynth.set(\vol, 50) }
        );

        ("Selected synth: " ++ ~synths[~currentSynth]).postln;
    }, '/synth/select');

    OSCdef(\globalMode, {|msg|
        ~isGlobalMode = msg[1].asInteger == 1;  // Convert to proper boolean
        ("Global mode: " ++ ~isGlobalMode).postln;
    }, '/mode/global');

    OSCdef(\pot1, {|msg|
        var value = msg[1].asFloat;  // Ensure float
        if(~isGlobalMode == true, {
            // Global volume
            ~sineSynth.set(\vol, value);
            ~fmSynth.set(\vol, value);
            ~pwmSynth.set(\vol, value);
        }, {
            // Frequency for current synth
            switch(~currentSynth,
                0, { ~sineSynth.set(\freq, value) },
                1, { ~fmSynth.set(\freq, value) },
                2, { ~pwmSynth.set(\freq, value) }
            );
        });
    }, '/pot/1');

    OSCdef(\pot2, {|msg|
        var value = msg[1];
        if(~isGlobalMode, {
            // Global reverb
            ~reverbSynth.set(\mix, value);
        }, {
            // Synth-specific parameter
            switch(~currentSynth,
                0, { ~sineSynth.set(\detune, value) },
                1, { ~fmSynth.set(\modIndex, value) },
                2, { ~pwmSynth.set(\width, value) }
            );
        });
    }, '/pot/2');

    OSCdef(\pot3, {|msg|
        var value = msg[1];
        if(~isGlobalMode, {
            // Global tempo
            ~tempoClock.tempo = value;
        }, {
            // Reverb room size
            ~reverbSynth.set(\roomsize, value);
        });
    }, '/pot/3');

    "Synth setup complete!".postln;
});
)