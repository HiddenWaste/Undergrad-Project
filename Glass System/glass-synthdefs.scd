(
// Piano SynthDef: Rich harmonics with medium sustain
SynthDef(\glassPiano, {
    arg
	//Standard values
	out = 0, freq = 440, amp = 0.1, att = 0.001, rel = 1, pan = 0,
	//These range from 0 to 1
	tone = 0.25, hollowness = 0;

	var hammer, snd, delay, tonefreq, env;

	env = Env.perc(att, rel, amp * 4, -1).ar(doneAction: 2);

	// Delay line times: freq, freq - 4 cents, freq + 3 cents. In the original this was done by converting freq to midi.
	delay = (1 / (freq * [2.pow(-0.04/12), 1, 2.pow(0.03/12)]));
	tonefreq = tone.linlin(0, 1, 1000, 5000);

	hammer = Decay2.ar(
		in: Impulse.ar(0.001),
		attackTime: 0.008,
		decayTime: 0.04,
		mul: LFNoise2.ar(freq: amp.linlin(0, 1, tonefreq, 2 * tonefreq), mul: 0.25)
	); //Try LFNoise1, LFNoise0, or even LFClipNoise above for a slightly grainier sound.

	snd = CombL.ar(hammer, delay, delay, 50 * amp);
	snd = HPF.ar(snd, hollowness.linlin(0, 1, 50, 1000));
	snd = snd * env;
	snd = Limiter.ar(snd);
	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "based on something posted 2008-06-17 by jeff, based on an old example by james mcc",
	category: \keyboards,
	tags: [\casio, \piano, \pitched]
	)
).add;

// Marimba SynthDef: Realistic wooden percussion with proper harmonics
SynthDef(\glassMarimba, {
    arg
	// Standard values
	freq = 440, out = 0, amp = 0.4, pan = 0, rq = 0.02,
        // Controls for BLowShelf
	shelffreq = 220, rs = 0.81, shelfamp = 2;

	var snd;

	snd = BPF.ar(
		in: Saw.ar(0),
		freq: freq,
		rq: rq);

	snd = BLowShelf.ar(
		in: snd,
		freq: shelffreq,
		rs: rs,
		db: shelfamp.ampdb);

	snd = Limiter.ar(snd) * amp;

	DetectSilence.ar(in: snd, doneAction: 2);

	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "unknown",
	category: \percussion,
	tags: [\percussion, \marimba, \pitched, \keyboard]
)
).add;

// Flute SynthDef: Breathy, pure tone with subtle modulation
SynthDef(\glassFlute, {
    arg scl = 0.2, freq = 440, ipress = 0.9, ibreath = 0.09, ifeedbk1 = 0.4, ifeedbk2 = 0.4, dur = 1, gate = 1, amp = 2;

	var kenv1, kenv2, kenvibr, kvibr, sr, cr, block;
	var poly, signalOut, ifqc;
	var aflow1, asum1, asum2, afqc, atemp1, ax, apoly, asum3, avalue, atemp2, aflute1;
	var fdbckArray;

	sr = SampleRate.ir;
	cr = ControlRate.ir;
	block = cr.reciprocal;

	ifqc = freq;

	// noise envelope
	kenv1 = EnvGen.kr(Env.new(
		[ 0.0, 1.1 * ipress, ipress, ipress, 0.0 ], [ 0.06, 0.2, dur - 0.46, 0.2 ], 'linear' )
	);
	// overall envelope
	kenv2 = EnvGen.kr(Env.new(
		[ 0.0, amp, amp, 0.0 ], [ 0.1, dur - 0.02, 0.1 ], 'linear' ), doneAction: 2
	);
	// vibrato envelope
	kenvibr = EnvGen.kr(Env.new( [ 0.0, 0.0, 1, 1, 0.0 ], [ 0.5, 0.5, dur - 1.5, 0.5 ], 'linear') );

	// create air flow and vibrato
	aflow1 = LFClipNoise.ar( sr, kenv1 );
	kvibr = SinOsc.ar( 5, 0, 0.1 * kenvibr );

	asum1 = ( ibreath * aflow1 ) + kenv1 + kvibr;
	afqc = ifqc.reciprocal - ( asum1/20000 ) - ( 9/sr ) + ( ifqc/12000000 ) - block;

	fdbckArray = LocalIn.ar( 1 );

	aflute1 = fdbckArray;
	asum2 = asum1 + ( aflute1 * ifeedbk1 );

	//ax = DelayL.ar( asum2, ifqc.reciprocal * 0.5, afqc * 0.5 );
	ax = DelayC.ar( asum2, ifqc.reciprocal - block * 0.5, afqc * 0.5 - ( asum1/ifqc/cr ) + 0.001 );

	apoly = ax - ( ax.cubed );
	asum3 = apoly + ( aflute1 * ifeedbk2 );
	avalue = LPF.ar( asum3, 2000 );

	aflute1 = DelayC.ar( avalue, ifqc.reciprocal - block, afqc );

	fdbckArray = [ aflute1 ];

	LocalOut.ar( fdbckArray );

	signalOut = avalue;

	OffsetOut.ar( 0, [ signalOut * kenv2, signalOut * kenv2 ] );

}).add;
)