(
s.waitForBoot({
    OSCdef.freeAll; // Clear any previous OSC defs to avoid duplicates
    s.meter;
    s.plotTree;

    // Global Buses and Variables
    ~masterBus = Bus.audio(s, 2);
    ~reverbBus = Bus.audio(s, 2);

    // Control buses for modulation sharing between synths
    ~modBuses = Array.fill(4, { Bus.control(s, 1) });

    // Arrays to store synth instances and their states
    ~synthInstances = Array.newClear(16);
    ~synthStates = Array.fill(16, { () }); // Events to store states

    // Project-Specific SynthDefs
    SynthDef(\fmSynth, {
        |out=0, gate=0, freq=440, amp=0.5, pan=0, modBus, modOut|
        var carrier, modulator, env, modEnv, sig;
        var modRatio = LFNoise2.kr(0.1).range(1, 4);
        var modDepth = LFNoise2.kr(0.05).range(200, 1000);

        modEnv = LFNoise2.kr(0.2).range(0.1, 1);
        modulator = SinOsc.ar(freq * modRatio) * modDepth * modEnv;
        carrier = SinOsc.ar(freq + modulator);

        env = EnvGen.kr(
            Env.asr(4, 1, 8),
            gate,
            doneAction: 2
        );

        sig = carrier * env * amp;
        sig = Pan2.ar(sig, pan);

        Out.kr(modOut, modEnv); // Share modulation
        Out.ar(out, sig);
    }).add;

    SynthDef(\granular, {
        |out=0, gate=0, freq=440, amp=0.5, pan=0, modBus|
        var trig, dur, rate, pos, sig, env, modIn;

        modIn = In.kr(modBus);
        trig = Dust.kr(LFNoise2.kr(0.1).range(10, 40));
        dur = LFNoise2.kr(0.2).range(0.02, 0.1);
        rate = LFNoise2.kr(0.05).exprange(0.5, 2);
        pos = LFNoise2.kr(0.1).range(0, 1);

        sig = GrainFM.ar(
            2,
            trig,
            dur,
            freq,
            freq * (1 + (modIn * 0.5)),
            pos,
            pan
        );

        env = EnvGen.kr(
            Env.asr(6, 1, 10),
            gate,
            doneAction: 2
        );

        sig = sig * env * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\noiseScape, {
        |out=0, gate=0, freq=440, amp=0.3, pan=0, modBus|
        var sig, env, modIn, filter;

        modIn = In.kr(modBus);
        sig = WhiteNoise.ar + PinkNoise.ar;

        filter = RLPF.ar(
            sig,
            freq * LFNoise2.kr(0.1).range(0.5, 2),
            LFNoise2.kr(0.05).range(0.1, 0.4)
        );

        env = EnvGen.kr(
            Env.asr(8, 1, 12),
            gate,
            doneAction: 2
        );

        sig = filter * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\drone, {
        |out=0, gate=0, freq=440, amp=0.4, pan=0, modBus|
        var sig, env, modIn, harmonics;

        modIn = In.kr(modBus);
        harmonics = Array.fill(6, { |i|
            var harmFreq = freq * (i + 1);
            var harmAmp = 1 / (i + 1);
            SinOsc.ar(
                harmFreq + (modIn * 10),
                0,
                harmAmp
            );
        }).sum;

        env = EnvGen.kr(
            Env.asr(10, 1, 15),
            gate,
            doneAction: 2
        );

        sig = harmonics * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\masterReverb, {
        |in, out=0, mix=0.5, room=0.8, damp=0.5|
        var sig, wet;

        sig = In.ar(in, 2);
        wet = FreeVerb2.ar(
            sig[0],
            sig[1],
            mix,
            room,
            damp
        );

        Out.ar(out, wet);
    }).add;

    // Wait for all SynthDefs to be loaded before creating the reverb
    s.sync;

    // Initialize master reverb
    Synth(\masterReverb, [
        \in, ~reverbBus,
        \out, 0,
        \mix, 0.4,
        \room, 0.8,
        \damp, 0.5
    ], addAction: \addToTail);

    // OSC Handlers
    OSCdef(\synthControl, { |msg, time, addr, recvPort|
        var index = msg[1];
        var gate = msg[2];
        var synthType = msg[3];
        var freq = msg[4] ?? 440;
        var amp = msg[5] ?? 0.5;
        var pan = msg[6] ?? 0;

        if(gate == 1, {
            // Start new synth
            ~synthInstances[index] = Synth(synthType, [
                \out, ~reverbBus,
                \gate, gate,
                \freq, freq,
                \amp, amp,
                \pan, pan,
                \modBus, ~modBuses[index % 4],
                \modOut, ~modBuses[(index + 1) % 4]
            ]);

            // Store state
            ~synthStates[index] = (
                \type: synthType,
                \freq: freq,
                \amp: amp,
                \pan: pan
            );

            // Send state to Processing
            NetAddr("localhost", 12000).sendMsg(
                "/synthState",
                index,
                synthType,
                freq,
                amp
            );
        }, {
            // Release existing synth
            if(~synthInstances[index].notNil, {
                ~synthInstances[index].set(\gate, 0);
                ~synthInstances[index] = nil;
                ~synthStates[index] = ();
            });
        });
    }, '/synthControl');
});
)