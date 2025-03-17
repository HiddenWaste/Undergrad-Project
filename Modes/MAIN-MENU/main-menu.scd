// Boot server with specific settings
s = Server.local;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;
s.options.memSize = 8192 * 16; // Increased memory for longer buffer
s.meter;

Server.killAll;

(
// Wait for server to boot
s.waitForBoot({
    var filepath, fullPath;

    // Clear any previous OSC defs
    OSCdef.freeAll;

    "Loading Reich analysis environment...".postln;

    // Debug: Print working directory
    "Current working directory:".postln;
    thisProcess.nowExecutingPath.dirname.postln;

    // Set up file paths
    filepath = "music-for-18-musicians-pulses.wav";
    fullPath = thisProcess.nowExecutingPath.dirname +/+ filepath;

    "Attempting to load file:".postln;
    ("Relative path:" + filepath).postln;
    ("Full path:" + fullPath).postln;

    if(File.exists(fullPath).not) {
        "ERROR: File not found! Please check file location".postln;
        ^this;
    };

    // Load the buffer
    ~reichBuffer = Buffer.read(s, fullPath);

    s.sync;

    // Verify buffer was loaded
    if(~reichBuffer.isNil) {
        "Buffer failed to load!".postln;
        ^this;
    };

    // Print buffer information
    "Buffer loaded successfully:".postln;
    ("Number of channels:" + ~reichBuffer.numChannels).postln;
    ("Number of frames:" + ~reichBuffer.numFrames).postln;
    ("Sample rate:" + ~reichBuffer.sampleRate).postln;
    ("Duration in seconds:" + ~reichBuffer.duration).postln;

    // Create analysis synth
    SynthDef(\reichAnalyzer, {
        arg bufnum=0, out=0;
        var sig, chain, onsets, volume, centroid;

        // Play the buffer
        sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);

        // Amplify the signal slightly
        sig = sig * 1.5;

        // Output the audio
        Out.ar(out, sig * 0.7);  // Reduced output volume slightly for safety

        // Analysis
        chain = FFT(LocalBuf(2048), Mix(sig));

        // Volume analysis
        volume = Amplitude.kr(Mix(sig));

        // Spectral centroid for overall frequency analysis
        centroid = SpecCentroid.kr(chain);

        // Onset detection for rhythm
        onsets = Onsets.kr(chain, 0.3);

        // Send analysis data via OSC
        SendReply.kr(Impulse.kr(30), '/reich/volume', [volume]);
        SendReply.kr(Impulse.kr(30), '/reich/centroid', [centroid]);
        SendReply.kr(onsets, '/reich/onset');
    }).add;

    s.sync;

    // Set up OSC responders
    OSCdef(\volumeTracker, {|msg|
        var vol = msg[3];
        NetAddr("127.0.0.1", 12000).sendMsg("/reich/volume", vol);
    }, '/reich/volume');

    OSCdef(\centroidTracker, {|msg|
        var cent = msg[3];
        NetAddr("127.0.0.1", 12000).sendMsg("/reich/centroid", cent);
    }, '/reich/centroid');

    OSCdef(\onsetTracker, {|msg|
        NetAddr("127.0.0.1", 12000).sendMsg("/reich/onset", 1);
    }, '/reich/onset');

    s.sync;

    // Start the analyzer with debug message
    "Creating analyzer synth...".postln;
    ~analyzer = Synth(\reichAnalyzer, [\bufnum, ~reichBuffer]);

    if(~analyzer.isPlaying) {
        "Analyzer synth is playing".postln;
    } {
        "Warning: Analyzer synth may not be playing".postln;
    };

    "Reich analysis ready!".postln;
});
)