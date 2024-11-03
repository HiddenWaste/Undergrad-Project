// osc_project.scd
s = Server.local;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

(
// Wait for all previous code to complete
s.waitForBoot({
	//Server.killAll; // Clears everything if rebooting..
    OSCdef.freeAll; // Clear any previous OSC defs to avoid duplicates

	"Booting server...".postln;

    // Wait for SynthDefs to be added
    Server.default.sync;
	s.meter;
	s.plotTree;

	// load Synths and Patterns
	// Load SynthDefs and Patterns
	"synthdefs.scd".standardizePath.load;
	"patterns.scd".standardizePath.load;

    // Set up OSC listener
    OSCdef(\simpleSynthTrigger, {|msg, time, addr, recvPort|

        // OSC Def that will play either a saw, sine, or pulse wave based on the first argument

        //var synthType = msg[1]; // Get the first argument from the OSC message
		Synth(\sine, [\freq, rrand(440, 880),
			\pan, Pexprand(-0.7, 0.7),
		]);

		//~rsaw.play;

	}, '/test');

	OSCdef(\kick_test, {|msg, time, addr, recvPort|

		Synth(\kick);

	}, '/kick');

	// Initialization Finished
	"Project ready:".postln;
    " - SynthDef loaded".postln;
    " - Sine on \test".postln;
	" - kick on \kick".postln;
    "You can now run the Python script".postln;
});
)
