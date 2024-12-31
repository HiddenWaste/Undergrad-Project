(
~rsaw = Pbind(
	\instrument, \bpfsaw,
	\freq, Pwrand([4, 8, 12, 20], [0.4, 0.4, 0.1, 0.1], inf),
	\atk, 0.1,
	\dur, 2,
	\amp, Pexprand(0.4, 0.7, inf),
	\out, Pexprand(-0.7, 0.7, inf),
	);

~chords = Pbind(
		\instrument, \bpfsaw,
		\dur, Pwhite(4.0,8.0,inf),
		\midinote, Pxrand([
			/*Scale.minor.degrees+60,
			Scale.minor.degrees+57,
			Scale.minor.degrees+53,
			Scale.minor.degrees+50,*/
			[23,35,54,63,64],
			[45,52,54,59,61,64],
			[28,40,47,56,59,63],
			[42,52,57,61,63],
		],inf),
		\detune, Pexprand(0.05, 0.2, inf),
		\cfmin, Pwrand([100, 300, 500], [0.6, 0.3, 0.1], inf),
		\cfmax, Pwrand([1500, 2000, 1000], [0.7, 0.2, 0.1], inf),
		\rqmin, Pexprand(0.01, 0.15, inf),
		\atk, Pwhite(2.0,2.5,inf),
		\rel, Pwhite(6.5,10.0,inf),
		\ldb, 6,
		\amp, Pexprand(0.15, 0.3, inf),
		\out, 0,
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
)