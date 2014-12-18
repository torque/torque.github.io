---
title: How not to be a Hacker
description: A simple n-step guide on how not to perform the action known as hacking.
date: 2014-12-18T23:45:58Z
template: article.jade
---

The other day I decided I wanted to rip some CDs for, uh,
myself[^disclaimer]. Because I am an unrepentant quality fiend, I was
compelled to ensure I produced accurate rips of the CDs. The go-to
program for this sort of thing on OS X is [X Lossless Decoder][xld]
(XLD), an application loaded to the brim with features for ensuring,
against all odds, that your CDs are accurately ripped.

Using XLD, I went through my collection and ripped upwards of twenty CDs
that I had ascertained had not been ripped before. Due to the required
quality of the rips, a single CD can take up to the real time length of
the CD to rip, as each song is actually read twice[^readtwice], and for
some reason my CD drive would only run at 2x read speed instead of 6x on
some CDs. Needless to say, it took quite a bit of time to complete all
of them, and I was happy to be done when I finished.

That was when I found out that my perfect rips were flawed. XLD creates
log files that contain a log of the ripping process, including any
errors encountered, and for reliability purposes, I needed these logs to
be signed by XLD to verify that, uh, I hadn't tampered with them. This
wouldn't have been a problem if it weren't for the fact that the log
signing plug-in for XLD is distributed separately and is not available
by default. None of my logs had been signed, and I wasn't about to go
and waste the time re-ripping the CDs just to get some dumb verification
hash.

It was time to figure out how to get XLD to sign these logs after they
had already been created. Which, when you think about it, kind of
completely defeats the signing process, as it allows for the logs to be
modified before they are signed. Unlike the rest of XLD, the log signing
plug-in is not open source.

### Run, LogChecker, Run

Let's take the initial approach of writing a short Objective-C program
to load the log signing plug-in, which is distributed as a bundle. If we
can load it, we should be able to execute the signing code arbitrarily.

```objectivec
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "XLDLogChecker.h"

int main( int argc, const char **argv ) {
	NSBundle *logCheckerBundle = [NSBundle bundleWithPath:[@"~/Library/Application Support/XLD/PlugIns/XLDLogChecker.bundle" stringByExpandingTildeInPath]];

	if ( ![logCheckerBundle load] ) {
		NSLog( @"Failed to load logChecker bundle." );
		return 1;
	}

	NSMutableString *logString = [[NSMutableString alloc] initWithString:@"I am a log file. Sign me."];

	Class logChecker = NSClassFromString( @"XLDLogChecker" );

	if ( logChecker ) {
		[logChecker appendSignature:logString];
		NSLog( @"%@", logString );
	}

	[logCheckerBundle release];
	[logString release];

	return 0;
}
```

This program has an unexpected result: it crashes somewhere in the
LogChecker code. Looking at the XLD source doesn't reveal any
information about why it wouldn't work. It's time to pull out the big
guns.

### Get Dissed, Assembler

The big guns, as it were, consist of [Hopper][hopper], a
disassembler/decompiler for OS X. It is sold for the bargain basement
price of 90 USD, which may sound like a lot until you consider that the
heavy hitter in the disassembly field, [IDA][ida], starts at 450 USD,
and that's for the basic version[^hexrays].

There is a free demo version of Hopper available that is
feature-complete, as long as you don't consider unimportant things like
being able to save or use the program for longer than thirty minutes at
a time to be features. I am not wealthy enough to justify blowing 90
bucks on a weekend project, so that's the version that I used.

With our big gun equipped, we load up the binary and navigate to the
function showing up at the top of the stack trace in the crashes. We
can see clearly what the problem is:

```assembly
_qwkoj1298oquwqwea89oi32r87hf:
00000c34 push ebp                                ; XREF=+[XLDLogChecker appendSignature:]+59, -[XLDLogChecker validateData:]+632
00000c35 mov  ebp, esp
00000c37 push edi
00000c38 push esi                                ; argument #2
00000c39 push ebx                                ; argument #1
00000c3a call 0xc3f
00000c3f pop  ebx                                ; XREF=_qwkoj1298oquwqwea89oi32r87hf+6
00000c40 sub  esp, 0xcc
00000c46 mov  dword [ss:ebp+var_B0], eax
00000c4c mov  dword [ss:ebp+var_B4], edx
00000c52 mov  dword [ss:esp], 0xfffffffe         ; argument #1 for method imp___jump_table__dlsym
00000c59 lea  eax, dword [ds:ebx-0xc3f+0x3b96]   ; "dlsym"
00000c5f mov  dword [ss:esp++[IconedCell ]], eax
00000c63 call imp___jump_table__dlsym
00000c68 mov  ecx, 0x8
...
```

The problem is we never actually took the time to learn x86 assembly. As
it is, that load of hot nonsense is getting us a whole lot of nowhere,
so the only route forward is to click on the "help, I'm illiterate"
button, which pops up a friendly window with psuedocode... which is
better, but not by a whole lot.

If we were, somehow, to acquire a copy of IDA with Hex-Rays[^dangerzone],
we would probably find that it does a pretty good job decompiling the
code. It might even produce something that looks like this:

```c
int qwkoj1298oquwqwea89oi32r87hf<eax>(void *a1<eax>, char *a2<edx>)
{
	/* snip (variable declarations) */
	v15 = dlsym((void *)0xFFFFFFFE, "dlsym");
	v2 = dlsym((void *)0xFFFFFFFE, "uncompress");
	if ( v2 ) {
		v3 = malloc(0x4000u);
		v17 = 0x899;
		v4 = v3;
		((void (__cdecl *)(void *, int *, _UNKNOWN *, signed int))v2)(v3, &v17, &temporary, 2201);
		((void (__cdecl *)(char *))((char *)v4 + 10032))(&v14);
		v5 = objc_msgSend(v13, "length");
		v6 = objc_msgSend(v13, "bytes");
		((void (__cdecl *)(char *, void *, void *))((char *)v4 + 9712))(&v14, v6, v5);
		((void (__cdecl *)(char *, _DWORD))((char *)v4 + 9840))(&v14, v16);
		free(v4);
	}
	/* snip (generating result) */
	return result;
}
```

Hey, that's nearly readable. So what it seems to be doing is unpacking a
compressed section of the executable into memory, and then trying to
execute specific offsets in that memory block, and the first one is the
one that causes the crash.

### Gee, Does That Sound Like a Defensive Measure to You?

Okay, obviously the author spent a little bit of time trying to make
sure that people would have a bit of trouble decompiling this plugin,
but we're onto him now. We can excise that compressed blob from the
executable using [our favorite hex editor][hexfiend] and write some
code to mimic the uncompressing function to dump it to a file.

```c
#include <dlfcn.h>
#include <stdio.h>

int main ( int argc, char **argv ) {
	void *uncompress = dlsym( RTLD_DEFAULT, "uncompress" );
	if ( uncompress ) {
		int maxSize = 0x4000, compressedSize = 0x899;
		void *uncompressedBlob = malloc( maxSize );
		void *compressedBlob = malloc( compressedSize );
		printf( "Max size is: %d\n", maxSize );

		FILE *blob = fopen( "blob", "r" );
		fread( compressedBlob, compressedSize, 1, blob );
		((void (__cdecl *)(void*, int*, void*, int))uncompress)( uncompressedBlob, &maxSize, compressedBlob, compressedSize );

		printf( "Max size is now: %d\n", maxSize );

		FILE *uBlob = fopen( "ublob", "w" );
		fwrite( uncompressedBlob, maxSize, 1, uBlob );
	} else {
		puts( "Idk what is going on." );
	}
	return 0;
}
```

Now we can load up the uncompressed blob in Hopper and look up those
offsets that it was trying to execute (`0x2730`, `0x25F0`, and
`0x2670`). We can, but we won't, because they're a horrifying reminder
of why you shouldn't execute memory, even if you aren't bad
guy[^anditdumb].

### An Aside

At this point, I decided to build XLD from source and discovered that my
build would crash when trying to run LogChecker. Some investigation of
the strings lying around in the uncompressed blob indicated a reference
to `dsa_pub.pem`, the public key file shipped with XLD. I thought
perhaps the plug-in checked this key to verify an official build, but
adding this key to my build didn't fix the crash.

It turns out that at least part of the reason XLD (and the LogChecker
bundle) are built only 32-bit is that 64-bit executables on OS X have
the NX bit set on heap memory, meaning this obfuscation trick wouldn't
work with a 64-bit executable[^oreven].

Finally, I was stumped. With no more ideas, I asked a friend if he had
any thoughts on where to go next. As it turns out, he did.

### Attack a Different Target

Trying to decompile the code and figure out what was going on failed to
get us anywhere besides the realization that the obfuscation techniques
employed by the LogChecer code were above our level of reverse
engineering skill. From there, the logical next step, seeing as we are
unable to use the plug-in directly, is to force XLD to use it for us.

mach_inject is an insidious tool for OS X that allows a program to
inject code into a running process. Dropbox, for example, uses it to
integrate with Finder due to a lack of public APIs provided by Apple. I
believe the main use it serves for Dropbox is creating the context
menus. Naturally, it works just as well for things that might not be
quite as legitimate.

### To Make a Long Story Short

mach_inject worked fine for injecting XLD. The problem is that
mach_inject is pretty inconvenient to use. Writing a separate
application to actually perform the code injection is required, and, on
top of that, the injection process either requires an administrator
password or a janky workaround involving some job privilege API. While
there is an example of this process included in the mach_inject
codebase, it's still a lot more infrastructure than should be necessary
to accomplish this task.

### Quit Trying to be So Smart and Start Being Clever

mach_inject is a tool for big boys, and to be honest, in this case it's
kind of like trying open a package with a chainsaw. Sure, a chainsaw may
be more versatile than a knife in the grand scheme of cutting things,
but a lot of the time it makes more sense to just use the knife.
Confusing metaphors aside, this problem can be solved by something that
requires far less boilerplate than mach_inject.

XLD is open source. We know that it can load and execute bundles, and we
know that all the loaded bundles have access to each other's code,
should they choose to use it. Source is a lot easier to read than
disassembly, so let's take a look at XLD's bundle loading process and
see if we notice anything.

```objectivec
/* XLDPluginManager.m */

- (id)init {
	[super init];
	plugins = [[NSMutableArray alloc] init];
	NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *bundleArr = [fm directoryContentsAt:[@"~/Library/Application Support/XLD/PlugIns" stringByExpandingTildeInPath]];
	int i;
	NSBundle *bundle = nil;

	for(i=0;i<[bundleArr count];i++) {
		BOOL isDir = NO;
		NSString *bundlePath = [[@"~/Library/Application Support/XLD/PlugIns" stringByExpandingTildeInPath] stringByAppendingPathComponent:[bundleArr objectAtIndex:i]];
		if([fm fileExistsAtPath:bundlePath isDirectory:&isDir] && isDir && [[bundlePath pathExtension] isEqualToString:@"bundle"]) {
			bundle = [NSBundle bundleWithPath:bundlePath];
			if(bundle) {
				if(![[bundle infoDictionary] objectForKey:@"NSPrincipalClass"]) continue;
				[dic setObject:bundlePath forKey:[[bundle infoDictionary] objectForKey:@"NSPrincipalClass"]];
			}
		}
	}
	/* snip (loading bundles from the XLD.app bundle) */
	[plugins addObjectsFromArray:[[dic allValues]sortedArrayUsingSelector:@selector(compare:)]];
}
```

It appears XLD is very secure and is perfectly willing to load all kinds
of code from a user-writable folder. The only checks it makes are that
each bundle it loads has a `NSPrincipalClass` key. Importantly, it
doesn't do any reliability checking (at least not in this code), and it
sorts the bundles it finds alphabetically by their `NSPrincipalClass`
value. The bundle code isn't actually loaded here, though, so we need to
look elsewhere to find that.

```objectivec
/* XLDController.m */
- (id)init {
	/* snip (initialization) */
	XLDPluginManager *pluginManager = [[XLDPluginManager alloc] init];
	decoderCenter = [[XLDecoderCenter alloc] initWithPlugins:[pluginManager plugins]];
	/* snip (initializing built-in classes) */

	NSArray *bundleArr = [pluginManager plugins];

	int i;
	NSBundle *bundle = nil;
	/* snip (initializing built-in encoders) */
	for(i=0;i<[bundleArr count];i++) {
		bundle = [NSBundle bundleWithPath:[bundleArr objectAtIndex:i]];
		if(bundle) {
			if([bundle load]) {
				if([[bundle principalClass] conformsToProtocol:@protocol(XLDOutput)] && [[bundle principalClass] canLoadThisBundle]) {
					output = [[[bundle principalClass] alloc] init];
					if([output respondsToSelector:@selector(configurations)]) [outputArr addObject:output];
					[output release];
				}
			}
		}
	}
	/* snip (special code for loading the updater bundle) */
	...
```

`XLDController` runs the bundle loading code and immediately passes it
off to the decoderCenter. The decoder center loads the bundles that
conform to the `XLDDecoder` protocol, but doesn't initialize them until
they are actually needed to open a file. All bundles that conform to the
`XLDOutput` protocol, however, are immediately initialized after being
loaded.

A quick review of where we are: it turns out that when it is launched,
XLD picks up any bundles placed in its PlugIn directory, sorts them by
name and then immediately initializes the principal class of all bundles
that subscribe to the `XLDOutput` protocol. Hopefully at this point you
can see where this is going.

It's worth noting that the LogChecker bundle is not initialized in this
loop. It is actually initialized later, in
`applicationDidFinishLaunching`, presumably because it adds a menu item.

```objectivec
Class logChecker = (Class)objc_lookUpClass("XLDLogChecker");
if(logChecker) {
	NSMenuItem *logcheckerItem = [[NSMenuItem alloc] initWithTitle:LS(@"Log Checker...") action:@selector(logChecker) keyEquivalent:@""];
	[logcheckerItem setTarget:[[logChecker alloc] init]];
	[[[[NSApp mainMenu] itemAtIndex:0] submenu] insertItem:logcheckerItem atIndex:6];
	[[[[NSApp mainMenu] itemAtIndex:0] submenu] insertItem:[NSMenuItem separatorItem] atIndex:7];
	[logcheckerItem release];
}
```

If that's all it takes to use it after it's been loaded, we could
probably do this ourselves.

```objectivec
/* Z.h */
#import <Foundation/Foundation.h>
#import "XLDOutput.h"
#import "BigMoney.h"

@interface Z : NSObject <XLDOutput>
- (instancetype)init;
@end

/* Z.m */
#import "Z.h"
@implementation Z
+ (NSString *)pluginName { return @"Z"; }
+ (BOOL)canLoadThisBundle { return YES; }
- (instancetype)init {
	if (self = [super init] ) {
		[NSThread detachNewThreadSelector:@selector(noWhammies) toTarget:[BigMoney new] withObject:nil];
	}

	return self;
}
/* snip (function stubs for the XLDOutput protocol) */
@end
```

We decide to descriptively name our plug-in Z, because we want to ensure
that it gets loaded after `LogChecker`, and really, when you get right
down to it, there aren't that many letters to choose from that come
after the letter "L". At least there aren't that many that are
sufficiently cool.

Well, it doesn't actually matter if it gets loaded before or after
`LogChecker` because of what we're doing. You may be saying to yourself,
"Hey, this bundle is just starting a new thread, not actually signing
logs. Why are we talking about it now?" You're right, of course. I just
wanted to break up the huge code blocks a little bit.

The point of making the new thread is so that any work we do that may
take a nontrivial amount of time, like accessing the filesystem, doesn't
stall the main XLD thread and block the application from launching. That
would be bad. Such a stall could be emulated by sticking
`usleep(10000000)` in the code. If it is placed in `Z.m`, XLD will
beachball for 10 seconds on startup. If it is placed in `BigMoney.m`,
which runs in its own thread, XLD does not stall at all.

```objectivec
/* BigMoney.h */
#import <Foundation/Foundation.h>

@interface BigMoney : NSObject {
	Class _logChecker;
	NSFileManager *_manager;
}

@property (readonly) Class logChecker;
@property (readonly) NSFileManager *manager;

- (instancetype)init;
- (void)noWhammies;
- (void)signLogFile:(NSString*)fileName;

@end

/* BigMoney.m */
@implementation BigMoney

@synthesize logChecker = _logChecker;
@synthesize manager = _manager;

- (instancetype)init {
	if ( self = [super init] ) {
		_logChecker = NSClassFromString( @"XLDLogChecker" );
		_manager = [NSFileManager defaultManager];
	}
	return self;
}

- (void)noWhammies {
	if ( [self logChecker] ) {
		NSString *logDir = @"/tmp/logsToSign";

		BOOL isDirectory = NO;
		if ( ![[self manager] fileExistsAtPath:logDir isDirectory:&isDirectory] ) {
			[[self manager] createDirectoryAtPath:logDir withIntermediateDirectories:NO attributes:nil error:nil];
		}

		NSArray *logDirList = [[self manager] contentsOfDirectoryAtPath:logDir error:nil];

		if ( logDirList ) {
			for ( int i = 0; i < [logDirList count]; ++i ) {
				NSString *logPath = [logDir stringByAppendingPathComponent:logDirList[i]];
				[self signLogFile:logPath];
			}
		}
	} else {
		NSLog( @"Log checker not loaded. Doing nothing." );
	}
}

- (void)signLogFile:(NSString*)fileName {
	BOOL isDirectory = NO;
	if (   [[self manager] fileExistsAtPath:fileName isDirectory:&isDirectory]
	    &&  !isDirectory
	    && [[fileName pathExtension] isEqualToString:@"log"]
	    && ![fileName hasSuffix:@"-signed.log" ] ) {
		NSMutableString *logFileContents = [NSMutableString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
		if ( logFileContents ) {
			NSLog( @"Signing log file: %@", fileName );
			NSString *signedLog = [[fileName stringByDeletingPathExtension] stringByAppendingString:@"-signed.log"];
			[[self logChecker] appendSignature:logFileContents];
			[logFileContents writeToFile:signedLog atomically:NO encoding:NSUTF8StringEncoding error:nil];
		}
	}
}
```

There's nothing fancy going on here. We get a list of all the files in
the directory `/tmp/logsToSign`, loop through that list of files and do
some basic verification of filename (checking for the extension `.log`,
but not the suffix `-signed.log`, as we don't want to sign a log twice).
We add all the matching files to a dictionary with each key being the
full path to the output file and the corresponding value being the
contents of that file. The output files have `-signed` appended to their
names.

To close things out, we loop over the dictionary, tell LogChecker to
append its signature, and write the signed files to disk.

A very basic proof-of-concept, but it works, and the only side-effect is
that it creates an unusable entry int the encoder configuration dropdown
menu. That's a small price to pay, in my opinion.

### The Moral of the Story

My initial plan was to use the LogChecker plug-in to sign logs, and when
it failed to work, I continued pursuing the notion that I could make it
work for me, rather than stepping back and taking a look at the problem
as a whole. If injecting code into XLD hadn't been brought up by someone
else, I may have given up completely, and at the very least I would have
taken a lot longer to arrive at a working solution.

It's worth noting that although the LogChecker plug-in itself was
apparently designed to be secure against abuse, XLD itself was not. The
log checker was easily exploitable not due to its own fault but because
of the program using it.

### Final Thoughts

Besides just appending signatures to log files that had already been
created, I had another motive for wanting to do this. XLD writes the
full path of each output file to the log file. If someone else were to
somehow get their hands on my log files, they could end up knowing
intimate details about the organization of my filesystem hierarchy, and
that would be terrible.

Ultimately, maybe that does count as fraud, but I wasn't editing the log
files to change any of the actually important information. A less
scrupulous individual than myself may be inclined to sign more heavily
modified log files, but that's not really my problem. While releasing
this may seem irresponsible on my part, anyone with a basic knowledge of
programming could accomplish this task on their own. This doesn't really
seem to be the sort of thing that demands responsible disclosure,
either. I personally think that signing logs is outrageously stupid
because _everyone rips CDs just for themselves, right? Right?_

[I've put the relevant code on github][code] (with some improvement),
and I've even included a [pre-compiled 32-bit bundle][bundle], though in
theory building it is as simple as opening the project in Xcode and
pressing the build button. It's certainly not polished, has absolutely
no error handling, and it might leak memory, but it works.

[^disclaimer]: Some names may or may not have been changed to protect
the guilty.

[^readtwice]: The extra read is a verification pass because apparently
it is extremely naïve to just trust the disk drive to read what is
actually on the CD.

[^hexrays]: The decompiler, Hex-Rays, is not included.

[^dangerzone]: We, of course, do not actually do this because illegally
acquiring a copy of IDA and Hex-Rays would probably be a felony, and
possibly constitute grand larceny, if you are the type of person who
treats software as property.

[^oreven]: At least one of the errors I encountered with my 32-bit
builds of XLD was one related to it refusing to execute memory. I
suspect that this may have been the real reason I couldn't get my
personal builds to work, though on other occasions, I saw a crash within
the memory (at least the disassembly blurb provided by lldb didn't exist
anywhere in the disassembled LogChecker binary). Basically, I don't know
what the hell was going on.

[^anditdumb]: There's additionally no point because as has already been
stated, I can't read x86 assembly (or any other kind of assembly for
that matter), and the decompiled psuedocode turns out to be a
labyrinthine horror (assuming that the binary blob was even being
disassembled correctly). What a shock.

[xld]: http://tmkk.undo.jp/xld/index_e.html

[hopper]: http://hopperapp.com

[ida]: https://www.hex-rays.com/products/ida/index.shtml

[hexfiend]: http://ridiculousfish.com/hexfiend/

[code]: https://github.com/torque/Z.bundle

[bundle]: https://github.com/torque/Z.bundle/releases/tag/v0.0.0
