#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use v5.14;
use utf8;
use POSIX;
use version;
$| = 1;

# Generate Roff from extracted V8 options
sub parseOpts {
	my $output = "";
	my %opts = ($_ = $1) =~ m/
		^ \h* --([-\w]+)
		(
			(?:\s+[^\n]+)?
			\h* \n
			\h+(?!--)\S+[^\n]+
		) \n
	/xsmg;
	
	# Generate a RegExp to match a switch reference
	my $matchKeys = join "|", sort {
		0 == index($b, $a) ? 1 : (0 == index($a, $b)) ? -1 : ($a cmp $b)
	} keys %opts;
	$matchKeys =~ s/[-_]/[-_]/g;
	$matchKeys = "--(?:no[-_])?(?:$matchKeys)";


	my $matchURL = qr~ \b
		(?:https?|s?ftp|ftps|file|smb|git|ssh|rsync|afp|nfs|(?:x-)?man(?:-page)?|gopher|txmt|issue|atom)
		://(?:(?!\#\w*\#)(?:[-:\@\w.,\~\%+_/?=\&\#;|!]))+
		(?<![-.,?:\#;])
		|mailto:(?:(?!\#\w*\#)(?: [-:\@\w.,\~\%+_/?=\&\#;|!]))+(?<![-.,?:\#;])
	~aix;

	for my $key (sort keys %opts) {
		$_ = $opts{$key};
		next if m/^\(deprecated/i or $key =~ m/^
			( help
			| testing-d8-test-runner
			| testing-bool-flag
			| concurrent-inlining
			) $
			/ix;
		
		
		# Strip brackets enclosing description
		s/^\s*\(\s*//;
		s/\)(?!\Z)(?=\n)//;
		
		# Capitalise first word of each sentence
		s/^\s*(\w)/\U$1/;
		
		# Break sentences across lines
		s/(?<!\be\.g|\bi\.e)\.\s+/.\n/gi;
		
		# Replace backslashes with \e sequence
		s/\\/\\e/g;
		
		# Extract metadata used by .V8 macro
		my $flag = "";
		$flag = " (WIP)"       if ($_ =~ s/\h*\(in progress(?: +\/ +experimental)?\)\.?\h*$/./m);
		$flag = " (INTERNAL)"  if ($_ =~ s/\h*\(for internal use only\)\.?\h*$/./m);
		$flag = " (TEST)"      if ($_ =~ s/\h* - testing only(?=\)?\h*$)//m);
		$flag = " (WIP)"       if ($_ =~ s/^Experimental:\h+(\w)/\u$1/i);


		# Typos and ad-hoc formatting fixes
		s/alingment/alignment/gi;
		s/^enable "harmony ([^"]+)"/Enable $1/gi;
		s/^Enable "Add ([^"\s]+)\s+(option to DateTimeFormat)"[,.\h]*$/Add\n.`` $1\n$2\n/gim;
		s/^(?:Increase |Decrease )?\K(Max|Min) /${1}imum /gi;
		s/reducing it's size/reducing its size/;
		s/only smi values/only SMI values/g;
		s/(?<=\s)an unit/a unit/g;
		s/(?<=\w with)\K(?=the \w)/ /g;
		s/\(in M\Kb(?=ytes\))/B/gi;
		s/^Indicate\Ks(?=\s)//gi;
		s/(?<=\s|^)etw stack walking for windows/ETW (Event Tracking for Windows) stack walking./i;

		# Format the switch's type and default value
		my $desc = $_;
		my $typeArgs = "";
		my %attr = $_ =~ m/
			\s+ (type):    \h+ (\S.*?)
			\h+ (default): \h+ (\S+.*?)
			\h* \Z
		/x;
		
		if(defined($attr{"type"})){
			my $type = $attr{"type"};
			my $default = $attr{"default"};
			my $hideType = 0;
			
			# A switch named `--foo` that defaults to `--foo`? Yeah, that's not vague at all
			$default =~ s/^--$key=("|')((?>(?!\1).)*)\1/$2/;
			$default =~ s/^--$key=([^"'\s]+)/$1/;
			
			# Boolean-type switch
			if("bool" eq $type){
				$default = "false" if $default eq "--no${key}";
				$default = "true"  if $default eq "--${key}";
				$hideType = 1;
				if($default eq "true"){
					$desc =~ s/^Shares(?=\h)/Share/i;
					$desc =~ s/^Allocate\Ks(?=\h)//i;
					$desc =~ s/^Also (?=\w)/\l/i;
					
					# Try to negate sentence, but don't try TOO hard
					unless(
						$desc =~ s/^Allow/Disallow/i  or
						$desc =~ s/^Disallow/Allow/i  or
						$desc =~ s/^Enable/Disable/i  or
						$desc =~ s/^Include/Exclude/i or
						$desc =~ s/^This mode tries/Try/i or
						$desc =~ s/^(Delay|Verify|Insert|Internali[sz])/Don't \l$&/i or
						$desc =~ s/^Re-?use(?= stack slots)/Discard/i or
						$desc =~ s/^(
							Abort|Add|Allocate|Automatically|Analy[zs]e|Cache|Compact|Elide|Expose|Fall[- ]?back|Filter|
							Free|Generate|Get|Increase|Inline|Intrinsify|Log|Optimi[sz]e|Perform|Pretenure|Promote|Protect|Put|
							Randomi[zs]e|Rehash|Run|Rewrite|Schedule|Share|Skip|Split|Trace|Track|Trigger|Use|Validate|Write
						)(?=\h|\R\.``)/Don't \l$1/xi
					){
						my $replacements_line = __LINE__ + 1;
						my %replacements = (
							"opt" => "Optimise code using the TurboFan optimising compiler. Alias of --turbofan.",
							"merge-background-deserialized-script-with-compilation-cache" => "Don't merge deserialised code cache data into existing scripts found within the Isolate compilation cache.",
							"feedback-allocation-on-bytecode-size" => "Use a variable-size budget scaled according to bytecode size for lazy feedback vector allocation.",
							"experimental-flush-embedded-blob-icache" => "Disable an experiment used when evaluating icache flushing on certain CPUs.",
							"trace-gc-heap-layout-ignore-minor-gc" => "Print trace line before and after minor-gc.",
							"write-code-using-rwx" => "Flip permissions to `rw` to write page instead of `rwx`.",
							"use-full-record-write-builtin" => "Don't force use of the full version of the\n.`` RecordWrite\n built-in.",
							"adjust-os-scheduling-parameters" => "Don't adjust OS-specific scheduling parameters for the isolate.",
							"allocation-buffer-parking" => "Disable buffer parking.",
							"baseline-batch-compilation" => "Don't batch compile Sparkplug code.",
							"concurrent-sparkplug" => "Don't compile Sparkplug code in background threads",
							"global-ic-updated-flag" => "Cease tracking of inline cache changes, normally used in tier-up heuristics.",
							"omit-default-ctors" => "Omit calls to default constructors in bytecode.",
							"shortcut-strings-with-stack" => "Don't shortcut strings during garbage collection with stacks",
							"text-is-readable" => "Don't try to read embedded `.text` sections in binary.",
							"concurrent-allocation" => "Don't concurrently allocate in old space.",
							"builtin-subclassing" => "Disable subclassing support in built-in methods.",
							"always-promote-young-mc" => "Don't promote young objects indiscriminately during mark-compact.",
							"concurrent-array-buffer-sweeping" => "Don't sweep array buffers concurrently",
							"concurrent-recompilation" => "Force synchronous optimisation of hot functions.",
							"idle-time-scavenge" => "Don't perform scavenges in idle time.",
							"log-colour" => "Don't use coloured output when logging.",
							"logfile-per-isolate" => "Use a single log-file for each isolate.",
							"fast-math" => "Don't enable faster, potentially less accurate, math functions.",
							"flush-bytecode" => "Don't flush bytecode that hasn't executed recently.",
							"parallel-scavenge" => "Disable parallel scavenging.",
							"polymorphic-inlining" => "Disable polymorphic inlining.",
							"prof-browser-mode" => "Turn off browser-compatible mode when profiling with --prof.",
							"reclaim-unmodified-wrappers" => "Don't reclaim unmodified wrapper objects that are otherwise unreachable.",
							"trace-maps-details" => "Don't log map details.",
							"turbo-allocation-folding" => "Disable TurboFan allocation folding.",
							"turbo-control-flow-aware-allocation" => "Don't consider control flow while allocating registers.",
							"turbo-loop-peeling" => "Disable TurboFan loop peeling.",
							"turbo-loop-rotation" => "Disable TurboFan loop rotation.",
							"turbo-loop-variable" => "Disable TurboFan loop variable optimisation.",
							"use-verbose-printer" => "Disable verbose printing",
							"wasm-atomics-on-non-shared-memory" => "Forbid atomic operations on non-shared WebAssembly memory.",
							"wasm-grow-shared-memory" => "Forbid growing shared WebAssembly memory objects.",
						);
						if(defined($replacements{$key})){
							$desc = $replacements{$key};
						}
						else{
							print STDERR "Unable to negate sentence for \e[4m--$key\e[24m: \e[7m$desc\e[27m\n";
							print STDERR "Please update \`\%replacements\` list in " . __FILE__ . " (line $replacements_line)\n";
							exit 1;
						}
					}
					$key = "no-$key";
				}
			}
			
			# String-type switch (might be a null-pointer)
			elsif("string" eq $type){
				unless($default =~ s/^nullptr$/NULL/i){
					$default =~ s/\\/\\e/g;
					$default =~ s/ /\\~/g;
					$default = "\\(lq${default}\\(rq";
				}
			}
			
			unless($hideType){
				$typeArgs = $type =~ /_/ ? $type : ucfirst($type);
				$typeArgs = "| $typeArgs $default";
			}
		}
		$desc =~ s/\n\h*(?:type|default):.+\Z//;
		$desc =~ s/(?<!\.)\Z/./;
		
		# Stupid ad-hoc fixes which will need updating
		{
			no warnings qw<uninitialized>;
			my $punct = '([.,!?]\)|\)[.,!?]|[.,;:!?])?';
			$desc =~ s'/' and ' if $key =~ /harmony-rab-gsab/;
			$desc =~ s/ wasm( |\.(?:$|\h))/ WASM$1/gi;
			$desc =~ s/\bmksnapshot\b/\\*(C!$&\\fP/g;
			$desc =~ s/(?<= non-)turbofan(?= code)/TurboFan/g;
			$desc =~ s/^Turbofan /TurboFan /gm;
			$desc =~ s/\bmaglev\b/\u$&/gi;
			$desc =~ s/ (static-roots\.h)\b/\n.`` $1 /;
			$desc =~ s/^(Print|Fast\h+forward)\Ks(?=\s)//gmi;
			$desc =~ s/\b(fast)\h+(forward)\b/$1-$2/gi;
			$desc =~ s/seriali\Kz(?=ation)/s/gi;
			$desc =~ s/128 to 256 bit/128\\(en to 256\\(enbit/gi;
			$desc =~ s/revectorisation for Web\Kassembly(?= SIMD)/\u$&/;
			$desc =~ s/ js-to-wasm / JS-to-WASM /g;
			$desc =~ s/^Check that there are not\b/Check there aren't/;
			$desc =~ s/\bheap_stats\b([.)]*)/\n.`` heap_stats $1\n/g;
			$desc =~ s/(?:code statistics after|handles at) \KGC\b| after \KGC\b/garbage collection/gi;
			$desc =~ s/^(Used with --perf-prof),\s*(load WASM source map and provide annotate support)/\u$2 when \l$1/i;
			$desc =~ s/^This mode is used for checking that V8 behaves predictably(\.?)/Check that V8 behaves predictably$1/i;
			$desc =~ s/^(?:Enable|Disable)( final types) as (default for )(wasm-gc)/Use$1 by $2\n.`` $3\n/i;
			$desc =~ s|; other heap size flags \(e\.g\. ([a-zA-Z0-9_]+)(?=\) take precedence)|".\nOther heap-size flags (e.g., --".($1 =~ tr#_#-#r)|egi;
			$desc =~ s/^Write\K (?=protect )/-/gi;
			$desc =~ s/ speciali\Kz(?=ation )/s/gi;
			$desc =~ s/^This flag is typically not set explicitly\K (?=but\b)/,\n/im;
			$desc =~ s/^Whether Maglev \Kresets(?= the)/should reset/i;
			$desc =~ s/^MinorMC task trigger in percent/MinorMC task trigger, specified as a percentage/i;
			$desc =~ s/Print verbose deopt\K(?= info)/imisation/i;
			$desc =~ s/^Run regexps with /Execute regular expressions using /i;
			$desc =~ s/^Temporary(?= disable)/Temporarily/gi;
			$desc =~ s/ source\K\h(?=map )|\bcontext\K (?=independent code)|\bcall\K (?=counts)/-/gi;
			$desc =~ s/ top\K\h(?=level[.\h])| tier(?:ing)?\K\h(?=up[.\h])|\btop\K\h+(?=tier)/-/gi;
			$desc =~ s/ type checks / type checking /g;
			$desc =~ s/^Print number of allocations and enable\Ks (analysis mode for) gc fuzz (?=testing)/ $1 GC fuzz-/i;
			$desc =~ s/\ADisable \Kglobal\.\Z/\n.JS global .\n/;
			$desc =~ s/ OS\K (specific scheduling) params\b/-$1 parameters/i;
			$desc =~ s/^Increase\Ks(?= the number)//gi;
			$desc =~ s/\((\d+) \+ (heap_growing_percent)\/100\)\.?/\n.EQ\n( $1 + $2 \/ 100 ).\n.EN\n/;
			$desc =~ s/(?<=Disallow )eval\h+(?=and friends\.?$)/\n.`` eval\n/mi;
			$desc =~ s/(?<=Maximum size of the heap \(in Mbytes\))\h+b(?=.+?semi.space.size\b)/.\nB/i;
			$desc =~ s/(?<=\s)max_(semi|old)_space_size(?=\s)/--max-$1-space-size/g;
			$desc =~ s/(?<=Expose )(async_hooks|freeBuffer|gc|injected-script-source\.js)\h+/\n.`` $1\n/g;
			$desc =~ s/Enables? optimi\Kz(ations?)(?=\h|$)/s$1/gm;
			$desc =~ s/for \Kspecific CPU\.$/a specific CPU\./im;
			$desc =~ s/ favo\Kr /u$&/gi;
			$desc =~ s/(?:^|\h)(?!res|s)(?:\w+i|analy)\Kz(ers?|ed?|ing|ations?)\b/s$1/gi;
			$desc =~ s/ \Kexternali[sz]e(?= )/\\*(CWexternalize\\fP/g;
			$desc =~ s/nesting child seriali\Kz/s/g;
			$desc =~ s/(?<=Print mutator utili)\Kzation\b/sation/;
			$desc =~ s/behavio\K(rs to ease correctness fuzzing:)\h+(A)/u$1\n\l$2/i;
			$desc =~ s/, gc(?= speed\.)|(?<=target )os\./\U$&/gi;
			$desc =~ s/(?<=target arch)(?=[.,])/itecture/gi;
			$desc =~ s/during initial compile\K(?= but regenerate)/,/i;
			$desc =~ s/(?<=Disable )(await) (?=taking 1 tick)/\n.JS $1\n/;
			$desc =~ s/ lazily\K (?=compiled\b)/-/gi;
			$desc =~ s/ to track in \KPOLYMORPHIC(?= state)/\\*(CW$&\\fP/g;
			$desc =~ s/Stress\K (?=test)\b/-/gi;
			$desc =~ s/(?<= )l(?=inux profiler)/L/;
			$desc =~ s/(?<=Dump )elf(?= objects)/ELF/;
			$desc =~ s/(?<= )h(?=armony )/H/;
			$desc =~ s/(?<= after lazy compil)e\b/ation/;
			$desc =~ s/\b(StubName),(NodeId)\b/\\(oq\\c\n.VAR $1 ,\\c\n.VAR $2 \\(cq.\n/;
			$desc =~ s/
				(ll_prof|ASM_UNIMPLEMENTED_BREAK|cputracemark)\b
				$punct \h*
			/\n.`` $1 $2\n/gx;
			$desc =~ s/\b
				( Error\.stack
				| Array\.fromAsync
				| ArrayBuffer
				| Atomics\.waitAsync
				| RangeError
				| JSON\.stringify
				| Promise(?:\.(?:allSettled|any))?
				| BigInt(?:\.[\$\w]+)*+
				| WebAssembly\.compile
				| (?i:sharedarraybuffer|ResizableArrayBuffer|GrowableSharedArrayBuffer)
				| (?:[A-Z]\w+)\.prototype (?:\.\w+)* (?:\.\{[^}]+\})?
				| Object\.fromEntries(?:\(\))?
				| Object\.hasOwn
				| import\.meta(?:\.\w+)*
				| ShadowRealm
				) $punct \h*
			/\n.JS $1 $2\n/gx;
			$desc =~ s/\h+"(Intl\..+?)\h+[vV](\d+)"/ version $2 of "$1"/;
			$desc =~ s/"(Intl\.\w+)"(\.?)/\n.JS $1 $2\n/g;
			$desc =~ s/"(Intl\.\w+)\h+([^"]+)"(\.?)/\n.JS $1\n$2$3/g;
			$desc =~ s/sharedarraybuffer/SharedArrayBuffer/g;
			$desc =~ s/ [Jj]avascript / JavaScript /g;
			$desc =~ s/ optimise call math\.min\/max with double array/ optimise calls to\n.JS Math.min\nor\n.JS Math.max\nwhen called with a double array/i;
			$desc =~ s/ built with\K (v8_enable_builtins_profiling=true)\b/\n.`` $1 /i;
			$desc =~ s/\bmaglev\b/\u$&/g;
			$desc =~ s/^Use TurboFan\K(?= fast string)/'s/i;
			$desc =~ s/ turboshaft / Turboshaft /gi;
			$desc =~ s/ use \Klibm trig functions\b/\n.`` libm\ntrigonometry functions/gi;
			$desc =~ s/, (?=useful for bisecting optimisation bugs)/.\n\l/gi;
			$desc =~ s/ from the\K(\.text) +(section(?:[.,]|$|\s))/\n.`` $1\n$2/g;
			$desc =~ s/near\K (\.text) (section)\b/\n.`` $1\n$2/g;
			$desc =~ s/, 0 for\K (NumberOfWorkerThreads)(\.?)$/\n.`` $1 $2\n/g;
			$desc =~ s/^(Trace Maglev inlining) \(verbose\)/Verbosely \l$1/;
			$desc =~ s/^Trace WASM revectorise\b/Trace WASM revectorisation/i;
			$desc =~ s/\bblock\K (?=profiling\b)/-/gi;
			$desc =~ s/"(well-formed) (JSON\.stringify)"\./$1\n.JS $2 ./;
			$desc =~ s/\.? \((for testing)\.?\)\.?/.\nUsed $1./i;
			$desc =~ s/^Specify the \K(name) (of the log file)[.,]?/\n.VAR $1\n$2.\n/i;
			$desc =~ s/\h*use '-' for console,?/Use \\*(CB\\-\\fP for console, and/;
			$desc =~ s/(?:and|,)\K\h*'\+'(?= for a temporary file)/\\*(CB+\\fP/;
			$desc =~ s/ (?:and +)?'\+'(?= for a temporary file\b)/and \\*(CB+\\fP/i;
			$desc =~ s/^Print WebAssembly code for function at \Kindex\b/\n.VAR $& /i;
			$desc =~ s/^Number of backtracks.*?before fall\K( back to experimental engine) (if )/ing$1.\nOnly used $2/;
			$desc =~ s/enable_experimental_regexp_engine_on_excessive_backtracks/--$&/;
			$desc =~ s/(?:^|\h)Use an \KIC /inline cache /gi;
			$desc =~ s/(?<=\h)[Ss]mi(?=\h)/\U$&/g;
			$desc =~ s/\h+switch\h+(?=statement)|clauses in the\K switch(\.)?/\n.JS switch $1\n/g;
			$desc =~ s/\hby \K(?=asm.js scanner)/the /i;
			$desc =~ s/ +(Heap::IsAllocationPending) that return (true|false)\h*(\.?)/\n.`` $1\nthat return\n.`` $2 $3/;
			$desc =~ s/\bJS->Wasm\b/JavaScript-to-WebAssembly/gi;
			$desc =~ s~{n / caller size}\.?~\n.EQ\n( N / caller-size ).\n.EN\n~i;
			$desc =~ s/, \K(?=in TF nodes\.?$)/measured /;
			$desc =~ s/\h+(mprotect|call_ref)(?=[\h.])\h*(\.|,)?/\n.`` $1 $2\n/g;
			$desc =~ s/dynamic tiering \K\(([^\(\)]+?)\.?$/($1)./;
			$desc =~ s/^Extra verbose/Use \l$&/;
			$desc =~ s/^Number of \Kgc(?=s )/GC/;
			$desc =~ s/ high\K (?=priority[\h.,])/-/gi;
			$desc =~ s/<value unavailable>([.,]?)\h*/\n.`` <value\\~unavailable> $1\n/g;
			$desc =~ s/concurrent \KOSR\b/on-stack replacement/g;
			$desc =~ s/"(RegExp Unicode sequence properties)"/$1/;
			$desc =~ s/\(0 means random\)\K\((with snapshots[^()]+)\)/.\n\u$1/;
			$desc =~ s/ <([a-z])> /\n.VAR \u$1\n/gi;
			$desc =~ s/ ([xX]) /\n.VAR \u$1\n/gi;
			$desc =~ s/ <([Nn])> times\b/\n.VAR \u$1\ntimes/gi;
			$desc =~ s/$matchKeys(?![-_\w])/"\\*(C!".($& =~ y|_|-|r)."\\fP"/eg;
			$desc =~ s/($matchURL)$punct/\n.LK "$1" $2\n/g;
			$desc =~ s/^(?:Disable|Enable) \Kexperimental async stacks/the experimental asynchronous stacks/i;
			$desc =~ s/^(?:Disable|Enable) \Kchange-Array-by-copy\.?$/\n.JS Array.prototype\nmethods that return a modified copy of the original./i;
			$desc =~ s/^(?:Disable|Enable) \Kjson parse with source\b/source-text access from\n.JS JSON.parse\nreviver functions/i;
			$desc =~ s/ +String#\{is,to}WellFormed\b/\n.JS String.isWellFormed\nand\n.JS String.toWellFormed\nmethods/g;
			$desc =~ s/(?<=\h)lazy new space shrinking\b/new lazy space-shrinking/;
			$desc =~ s/(?<=\h)optional features on the simulator for testing: (\S+) or ([^\s.]+)\.?\h*$/optional simulator features for testing.\nSupported values are \\(lq$1\\(rq and \\(lq$2\\(rq./gi;
			$desc =~ s/(?<=\h)(gc[-_]interval|stress[-_]compaction)(?!-)\b/"\\*(C!--".($& =~ tr#_#-#r)."\\fP"/eg;
			$desc =~ s/code-<pid>-<isolate id>(\.asm\.?)/\n.RI \\(lqcode- pid - isolate-id $1\\(rq/g;
			$desc =~ s/(?<=\h)(random)\(0,\h*([xX])\)\h*/\\*(CB$1\\fP\\*(CW(0,\\fP\n.VAR $2 )\n/g;
			$desc =~ s# by \K(bytecode\.length)/X\.?#"\n.EQ\n( ".($1 =~ s/\./"\\."/r)." / X ).\n.EN\n"#ie;
			$desc =~ s/\bC\+\+/\\*(C+/g;
			$desc =~ s/\btop-level\h+\Kawait($punct)?/\n.`` await $1\n/g;
			$desc =~ s/(?<=Disable namespace exports \()[^)\n]+(?=\))/"\\f(CW" . ($& =~ tr|'"|"'|r) . "\\fP"/e;
			$desc =~ s/^Disable \Khashbang(?= syntax\.$)/support for interpreter directive (hashbang)/m;
			$desc =~ s/(?:Can|Don|Hasn|Won|Shouldn|Wouldn)\K'(?=t )/\\(cq/gi;
			$desc =~ s/^(?=New background|Less compaction)./Use \l$&/im;
			$desc =~ s/ease correctness fuzzing: \KAbort/\L$&/i;
			$desc =~ s/prototype inline small WASM(?= functions)/prototype inlining of small WebAssembly/i;
			$desc =~ s/^(Include|Exclude)\Ks(?=\h)//gmi;
			$desc =~ s/^(Disable|Enable) "(Add calendar and numberingSystem to DateTimeFormat)"/$2/mi;
			$desc =~ s/^(Disable|Enable) "(DateTimeFormat) (other) (calendars)"/$1 $3 $2 $4/mi;
			$desc =~ s/^(Disable|Enable) "(Unified Intl.NumberFormat )(Features)"/$1 \l$2\l$3/mi;
			$desc =~ s/^(Disable|Enable) "(Intl) (DurationFormat) API"([.,]?)/$1 $2.$3 API$4/i;
			$desc =~ s/^(Disable|Enable) "(JavaScript iterator helpers)"/$1 $2/i;
			$desc =~ s/^(Disable|Enable)s /$1 /gmi;
			$desc =~ s/^(?:Disable|Enable) \K"(\n\.JS[^\n]+)\n"([.,])/$1 $2/gm;
			$desc =~ s/^(?:Disable|Enable) \K"(DateTimeFormat) (formatRange)"/\n.JS $1.$2 /m;
			$desc =~ s/^(?:Disable|Enable) \K"(dateStyle) (timeStyle)( for DateTimeFormat)"/\\f(CW$1\\fP and \\f(CW$2\\fP$3/m;
			$desc =~ s/space: \Klimit - size\.?/\n.EQ\n( "limit\\~" - "\\~size" ).\n.EN\n/i;
			$desc =~ s/^Allow only natives(?= explicitly\b)/Only allow natives that\\(cqre/gi;
			$desc =~ s/Perform\K the(?= script streaming)//i;
			$desc =~ s/ cpu / CPU /i;
			$desc =~ s/: (default) or (cpuid)([,.])?/:\n.`` $1\nor\n.`` $2 $3\n/;
			$desc =~ s/ Turbofan(?=[\h,.])/ TurboFan/g;
			$desc =~ s/ wall\K (?=time\b)/-/i;
			$desc =~ s/^Enable size optimisations for \Kthe (?=code)//i;
			$desc =~ s/that are not included/that aren't included/i;
			$desc =~ s/ a WASM(?= memory\s)/ a WASM instance's/i;
			$desc =~ s/test \K(parsing) on (background)/$2 $1/i;
			$desc =~ s/^Add \K(calendar) and (numberingSystem)(?= to DateTimeFormat\.)/\\f(CW$1\\fP and \\f(CW$2\\fP/m;
			$desc =~ s/^(?!\.).*?\s\K(Intl\.NumberFormat|DateTimeFormat)([.,]|(?:\h+|$))/\n.JS $1 $2\n/gm;
			$desc =~ s/^\.JS +\S+\K\h+(?=[^.,\s])//gm;
			$desc =~ s/^\.JS.+?\K(?:\h{2,}(?=[.,]\h*$)|(?<=\w)(?=${punct}$))/ /gm;
			$desc =~ s/(?<=\w)'(?=s )/\\(cq/g;
			$desc =~ s/(\n\.(?:``|JS).+)\n+/$1\n/g;
			$desc =~ s/ (externref|memory64)([.,]|(?=\s|$) *)/\n.`` $1 $2\n/g;
			$desc =~ s/^Disable\K atomics(\.?)/\n.JS Atomics $1\n/i;
			$desc =~ s/\.\nU(?=se a fixed suppression string)/,\nand u/is;
			$desc =~ s/\bstack\K scanning in(?= scavenge\b)/-scanning during/i;
			$desc =~ s/^Freelist strategy to use\K:((?:\s+[0-9]:FreeList\w+\.?\h*)*)/.\nSupported values and their meanings are:\n.sp 1\n.nf\n$1\n.fi\n/m;
			$desc =~ s/(?:^|\s+)([0-9]):(FreeList[A-Z]\w+)[.\h]*/\n\\fR$1\\fP\t\\*(C!$2\\fR/gm;
			$desc =~ s/^(?-x:Emit (data about basic block usage in built)ins to (v8\.log\b)) \s*
				\((?-x:(requires that V8) was built with (v8_enable_builtins_profiling=true))\)\.$
				/ Write\ $1-ins\ to\n\.``\ $2 .\n\u$3\ be\ built\ with\n.``\ $4 ./mix;
			$desc =~ s/containing basic block counters for built\Kins\.\s*/-ins /gi;
			$desc =~ s/^([12])=([^\s.,]+)[.,]?$/\\*(C?$1\\fP selects \\*(C!$2\\fP,/igm;
			$desc =~ s/^Anything else=([^\s.,]+)[.,]?$/and any other value selects \\*(C!$1\\fP.\n/igm;
			$desc =~ s/jobs\K( but throw away) result/,$1 the result/;
			$desc =~ s/\h+\(d8 only\)\h+\((requires [^()]+?)\)\.?$/\n.RB ( d8 1\nonly).\n\u$1./gi;
			$desc =~ s/^Allocation buffer parking\.$/Disable \l$&/mi;
			$desc =~ s/^Enable prototype (assume|allow)(?=\h)/\u$1/gi;
			$desc =~ s/ +(ref\.cast)\b\h*/\n.`` $1\n/gi;
			$desc =~ s/'until end of block'/\\(lquntil end-of-block\\(rq/i;
			$desc =~ s/^(?:Disable|Enable) prototype skip\K(?= )/ping of/gi;
			$desc =~ s/^Enable \Kprototype relaxed simd /relaxed SIMD /i;
			$desc =~ s/\bv8_enable_ignition_dispatch_counting\b/\\*(C!--v8-enable-ignition-dispatch-counting\\fP/g;
			$desc =~ s/\h+array find last +(?=helpers\b)/\n.JS Array.findLast\n/gi;
			$desc =~ s/\h+error cause +(?=property\b)/ the\n.JS Error.cause\n/gi;
			$desc =~ s/\h+"Intl (BestFitMatcher)"\h*(\.)?/ the\n.JS Intl\n.`` $1\nalgorithm./i;
			$desc =~ s/\h+"Intl (Enumeration API)"/ the\n.JS Intl\n\l$1/i;
			$desc =~ s/\h+"Intl (Locale Info)"\h*\.?/\n.JS Intl\nlocale info./i;
			$desc =~ s/^Enable \K"Temporal"\.?/\n.JS Temporal ./i;
			$desc =~ s/ +(call\.ref) +/\n.`` $1\n/g;
			$desc =~ s/ +during +eval\K\.?$/uation./g;
			$desc =~ s/ +during +streaming\K +compilation(?=\.$)//;
			$desc =~ s/ visitor behavio\Kr/ur/gi;
			$desc =~ s'/ic(?=-processor)'/IC';
			$desc =~ s/ parallel \Kcompile(?= tasks)/compilation/gi;
			$desc =~ s/ wait \K\[ms\]/(in milliseconds)/i;
			$desc =~ s/\h*\b(Script::Run)(?!:|->)\b\h*([,\.])?/\n.`` $1 $2\n/g;
			$desc =~ s/\h+\Kgc(?= tasks)/GC/gi;
			$desc =~ s/\h+\K>=(?=\h*\d+GB)/\\(rA/gi;
			$desc =~ s/\h+\K<=(?=\h*\d+GB)/\\(lA/gi;
			$desc =~ s/^\h+//g;
			$desc =~ s/\n+$//;
			
			if($key eq "no-regexp-tier-up"){
				$desc  = "Disable regexp interpreter.\n";
				$desc .= "The default behaviour is to tier-up to the compiler after the number of executions set by";
				$desc .= " \\*(C!--regexp-tier-up-ticks\\fP";
			}
			elsif($key eq "no-concurrent-cache-deserialization"){
				$desc = "Don't deserialise code caches in background threads.";
			}
			elsif($key eq "liftoff-only"){
				$desc = q'Don\(rqt use TurboFan compilation for WebAssembly.';
			}
			elsif($key eq "allocation-buffer-parking"){
				$desc =~ s/^Disable /Enable /;
			}
			elsif($key eq "heap-profiler-show-hidden-objects"){
				$desc = "Use\n.`` native\nnode-type in snapshots instead of the\n.`` hidden\ntype.";
			}
			elsif($key eq "vtune-prof-annotate-wasm"){
				$desc = "Load WebAssembly source-map and provide annotate support. Used when\n.`` v8_enable_vtunejit\nis enabled.\nExperimental.";
			}
			elsif($key eq "fuzzing"){
				$desc = "Cause intrinsics to fail silently by returning\n.`` undefined\nfor invalid usage.";
			}
			elsif($key eq "enable-experimental-regexp-engine"){
				$desc = 'Enable experimental regular expression engine for regexes which use the \*(C!/l\fP (\(lqlinear\(rq) flag.';
			}
			elsif($key eq "allow-overwriting-for-next-flag"){
				$desc = "Temporarily disable flag contradiction so the next flag gets overwritten.";
			}
			elsif($key eq "abort-on-contradictory-flags"){
				$desc = "Abort program if run with a contradictory combination of flags.";
			}
			elsif($key eq "no-abort-on-contradictory-flags"){
				$desc = "Allow program to run even when called with contradictory flags.";
			}
			elsif($key eq "experimental-wasm-ref-cast-nop"){
				$desc = "Enable unsafe, experimental use of the\n.`` ref.cast_nop\nWebAssembly op-code.";
			}
			elsif($key eq "separate-gc-phases"){
				$desc = "Prevent overlapping between young and full garbage collection phases.";
			}
			elsif($key eq "no-harmony-symbol-as-weakmap-key"){
				$desc = "Forbid the use of\n.JS Symbol\nvalues as\n.JS WeakMap\nkeys.";
			}
			elsif($key eq "max-opt"){
				($desc = qq|
					Set the maximal optimisation tier:
					.TS
					l blx .
					0	Ignition/interpreter
					1	Sparkplug/Baseline
					2	Maglev
					3	TurboFan
					3+	Any
					.TE
				|) =~ s/^\s+|\s+$|(?<=\R)\t+//g;
			}
		}
		
		$output .= ".V8 ${key}${flag} $typeArgs\n";
		$output .= "$desc\n\n";
	}
	$output =~ s/\h+$//gm;
	$output =~ s/\n+$//;
	return $output;
}

# Locate the most recent version of V8's shell
sub findV8 {
	no warnings qw< uninitialized >;
	
	# Respect manual overrides
	if(defined $ENV{"V8_PATH"}){
		(my $cmd = $ENV{"V8_PATH"}) =~ s/'/'\''/g;
		return qq|'$cmd'|;
	}
	my %versions = ();
	foreach("d8", "v8", "v8-debug"){
		`command 2>&1 >/dev/null -v $_`;
		next if $?;
		(my $ver = `$_ -e 'print(version());'`) =~ s/\s+$//;
		$versions{$ver} = $_ if $ver =~ m/^[0-9]+(?:\.[0-9]+)*+$/;
	}
	my @keys = sort { version->parse($b) <=> version->parse($a) } keys %versions;
	return $versions{$keys[0]};
}

# No file-path supplied
unless($ARGV[0]){
	say "Usage: $0 /path/to/v8.1";
	exit 1;
}

# Locate and load man-page source
my $pagePath = $ARGV[0];
-f $pagePath or die "Can't read $pagePath: bailing";

my $V8 = findV8;
$_ = `$V8 --help`;
s/\A(\w+=\d+\s*)+\n//;
s/^\s*Synopsis:(.*?)\n(?=Options:)//si;
s/\s*Options:(.+?)\s*\Z//si;
my $opts = parseOpts($_);

my $source = do {{
	local $/ = undef;
	open(my $fh, $pagePath);
	join "", <$fh>
}};

# Extract the document's header and footer
(my $head) = ($source =~ m/(\A.+\n\.\\" BEGIN SCRAPE\n)/s);
(my $foot) = ($source =~ m/(\n\.\\" END SCRAPE\n.+\Z)/s);

# Update revision date and version string
(my $version) = (`echo exit | $V8 --version` =~ /^V8 version v?([\d.]+)$/mi);
if($version){
	my ($day, $month, $year) = (localtime())[3..5];
	$month = POSIX::strftime("%B", 0, 0, 0, $day, $month, $year);
	$year += 1900;
	$head =~ s/^\.TH V8 1 \K"[^"]*" "[^"]*"/"$month $day, $year" "V8 $version"/m;
	$foot =~ s/\\\(co 2016-\K\d+(?=,\n\.MT\h+gardnerjohng)/$year/;
}

# Piece it back together
open(my $fh, ">", $pagePath) or die("Can't reopen man-page: $!");
print $fh $head . $opts . $foot;
close($fh);
