// Christmas Soundscape SuperCollider Script

(
// Server config and boot
s.waitForBoot({
    // Clear previous patterns
    Pdef.all.do(_.clear);

    // SynthDefs
    SynthDef(\bellSynth, {
        |out=0, freq=7440, amp=0.5, att=0.01, dec=1, sus=0.3, rel=4, pan=0|
        var env, sig;
        env = EnvGen.kr(Env.new([0,1,sus,0], [att,dec,rel], [-4,3,-4]), doneAction: 2);
        sig = SinOsc.ar(freq) * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);

        // Send OSC message to Processing
        SendReply.kr(Impulse.kr(0), '/bell');
    }).add;

    SynthDef(\chimeSynth, {
        |out=0, freq=440, amp=0.3, att=0.01, dec=0.3, sus=0.5, rel=2, pan=0|
        var env, sig;
        env = EnvGen.kr(Env.new([0,1,sus,0], [att,dec,rel], [-4,-2,-4]), doneAction: 2);
        sig = SinOsc.ar([freq, freq*2.0, freq*3.0, freq*4.2]) * env * amp;
        sig = sig.sum * 0.25;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);

        // Send OSC message to Processing
        SendReply.kr(Impulse.kr(0), '/chime');
    }).add;

    SynthDef(\jingleSynth, {
        |out=0, freq=440, amp=0.4, att=0.01, dec=0.1, sus=0.1, rel=0.5, pan=0|
        var env, sig;
        env = EnvGen.kr(Env.new([0,1,sus,0], [att,dec,rel], [-2,-2,-2]), doneAction: 2);
        sig = SinOsc.ar(freq * [1, 2.01, 3.02]) * env * amp;
        sig = sig.sum * 0.33;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);

        // Send OSC message to Processing
        SendReply.kr(Impulse.kr(0), '/jingle');
    }).add;

    s.sync;

    // Define musical patterns
    ~christmasScale = Scale.major;
    ~root = 60;  // Middle C

    // Main bell melody pattern
    Pdef(\bellPattern,
        Pbind(
            \instrument, \bellSynth,
            \scale, ~christmasScale,
            \octave, 5,
            \degree, Pseq([0, 2, 4, 0, 4, 2, 0], inf),
            \dur, Pseq([1, 0.5, 0.5, 1, 0.5, 0.5, 2] * 2, inf),
            \amp, 0.3,
            \pan, Pwhite(-0.7, 0.7),
        )
    );

    // Chime accompaniment pattern
    Pdef(\chimePattern,
        Pbind(
            \instrument, \chimeSynth,
            \scale, ~christmasScale,
            \octave, 6,
            \degree, Pseq([0, 4, 7, 4], inf),
            \dur, Pseq([4], inf),
            \amp, 0.2,
            \pan, Pwhite(-0.5, 0.5),
        )
    );

    // Jingle bells effect pattern
    Pdef(\jinglePattern,
        Pbind(
            \instrument, \jingleSynth,
            \scale, ~christmasScale,
            \octave, 7,
            \degree, Pseq([0, 0, 0, -1, 0, 2], inf),
            \dur, Pseq([0.25, 0.25, 0.5, 0.25, 0.25, 1] * 2, inf),
            \amp, 0.15,
            \pan, Pseries(-1, 0.2, inf).wrap(-1, 1),
        )
    );

    // Start patterns
    Pdef(\bellPattern).play;
    Pdef(\chimePattern).play;
    Pdef(\jinglePattern).play;

    // OSC responders for visual feedback
    OSCdef(\bellTrigger, {|msg, time, addr, recvPort|
        "Bell triggered visual effect".postln;
    }, '/bell');

    OSCdef(\chimeTrigger, {|msg, time, addr, recvPort|
        "Chime triggered visual effect".postln;
    }, '/chime');

    OSCdef(\jingleTrigger, {|msg, time, addr, recvPort|
        "Jingle triggered visual effect".postln;
    }, '/jingle');
});
)