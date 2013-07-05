
//
//  AppDelegate.m
//  Sammelbild
//
//  Created by Enie Weiß on 15.11.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import "AppDelegate.h"
#import "MosaicImageView.h"
#import "Mosaic.h"
#import "ImageCollection.h"
#import "SettingsScrollView.h"
#import "NSFileManager+DirectoryLocations.h"

#import "ClientGLView.h"
#import <Syphon/Syphon.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [_settingsScrollView setDocumentView:_settingsView];
    
    [_referenceTokenField setToolTip:NSLocalizedString(@"referenceTooltip", @"")];
    [_sourceTokenField setToolTip:NSLocalizedString(@"sourceTooltip", @"")];
    
    [_addReferenceButton.cell setBezelStyle:NSTexturedSquareBezelStyle];
    [_addReferenceButton.cell setButtonType:NSMomentaryChangeButton];
    
    [_addSourceButton.cell setBezelStyle:NSTexturedSquareBezelStyle];
    [_addSourceButton.cell setButtonType:NSMomentaryChangeButton];
    
    [self loadSettings];
    
    _mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(_imageWidthField.intValue, _imageHeightField.intValue)];
    
    [[_glView window] setContentMinSize:(NSSize){475.0,270.0}];
	//[[_glView window] setDelegate:self];
}

- (IBAction)mosaicize:(id)sender;
{
    [_imageView setImage:NULL];
    [_imageView display];
    
    
    //TODO: don't use self in blocks (but actually the app delegate will always be there..)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),^
    {                   
        if(![_sourceTokenField.objectValue isEqualToArray:_sources] ||
           _tilesCountField.stringValue.intValue!=_tilesCount ||
           _subdivisionLevelField.stringValue.intValue != _subdivisionLevel ||
           _imageWidthField.stringValue.intValue != _imageWidth ||
           _imageHeightField.stringValue.intValue != _imageHeight ||
           _tileWidthField.stringValue.intValue != _tileWidth ||
           _tileHeightField.stringValue.intValue != _tileHeight)
        {
            [_progressIndicator startAnimation:self];
            _imageWidth = _imageWidthField.intValue;
            _imageHeight = _imageHeightField.intValue;
            _tilesCount = _tilesCountField.intValue;
            _subdivisionLevel = _subdivisionLevelField.intValue;
            _sources = _sourceTokenField.objectValue;
            _tileWidth = _tileWidthField.intValue;
            _tileHeight = _tileHeightField.intValue;
            
            [_mosaicImage setSize:NSMakeSize(_imageWidth, _imageHeight)];
            
            CGSize tileSize = CGSizeMake(_tileWidth,_tileHeight);
            
            BOOL isDir;
            if([[_sources objectAtIndex:0] isKindOfClass:[NSURL class]] && [[NSFileManager defaultManager]
                fileExistsAtPath:((NSURL*)[_sources objectAtIndex:0]).path isDirectory:&isDir] && isDir)
                            self.ImageCollection = [[ImageCollection alloc] initWithSource:_sources tileSize:tileSize subdivisionLevel:_subdivisionLevel];
            
            //plist is already read
            /*else
            {
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfURL:[_sources objectAtIndex:0]]];
                self.imageCollection = [unarchiver decodeObjectForKey:@"imageCollection"];
                [unarchiver finishDecoding];
            }*/

            [_progressIndicator stopAnimation:self];
        }
        
        NSArray *tokens = [_referenceTokenField objectValue];
        
        if(tokens.count && _imageCollection && _tileWidth && _tileHeight && _imageWidth && _imageHeight)
        {
            [_progressIndicator startAnimation:self];
            [_imageCollection setTolerance:_toleranceField.floatValue];
            
            _mosaic = [[Mosaic alloc] init];
            _mosaic.checkNeighborDistance = _checkNeighborDistanceField.intValue;
            _mosaic.onlyColors = _onlyColorsCheckButton.state;
            _mosaic.monochrome = _monochromeCheckButton.state;
            
            _imageCollection.checkNeighborDistance = _checkNeighborDistanceField.intValue;
            
            for (id token in tokens)
            {
                NSString *referencePath;
                if([token isKindOfClass:[NSURL class]])
                    referencePath = [(NSURL*)token path];
                else
                    referencePath = token;
                
                BOOL isDir;
                if([[NSFileManager defaultManager]
                      fileExistsAtPath:referencePath isDirectory:&isDir] && isDir)
                {
                    NSArray *dirContents = [[NSFileManager defaultManager]
                                            directoryContentsAtPath:referencePath];
                    
                    [_imageCollection setDestinationPath:referencePath];
                    
                    NSLog(@"start creating mozaics");
                    for(NSString *filePath in dirContents)
                    {
                        NSString *fullPath = [referencePath stringByAppendingPathComponent:filePath];
                        if([filePath characterAtIndex:0] =='.' || ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir))
                            continue;
                        
                        //release the previous reference Image;
                        if(_referenceImageRef)
                            CGImageRelease(_referenceImageRef);
                        
                        NSURL * urlInputFile = [NSURL fileURLWithPath:fullPath];
                        CGImageSourceRef cgImageSourceRef	= CGImageSourceCreateWithURL ((__bridge CFURLRef)urlInputFile,NULL);
                        _referenceImageRef = CGImageSourceCreateImageAtIndex(cgImageSourceRef,0,NULL);
                        CFRelease(cgImageSourceRef);	// no longer needed
                        if(_referenceImageRef == NULL)
                            NSLog(@"errror: no reference image");
                        else
                            [_mosaic mosaicImageWithSize:NSMakeSize(_imageWidth, _imageHeight)collection:_imageCollection referenceImage:_referenceImageRef tileSize:NSMakeSize(_tileWidth, _tileHeight) imageView:_imageView saveName:filePath];
                    }
                    NSLog(@"done creating mozaics");
                }
                else
                {
                    if(tokens.count > 1)
                        [_imageCollection setDestinationPath:referencePath];
                    else
                        [_imageCollection setDestinationPath:nil];
                    
                    if(_referenceImageRef)
                        CGImageRelease(_referenceImageRef);
                    
                    NSURL * urlInputFile = [NSURL fileURLWithPath:referencePath];
                    CGImageSourceRef cgImageSourceRef	= CGImageSourceCreateWithURL ((__bridge CFURLRef)urlInputFile,NULL);
                    _referenceImageRef = CGImageSourceCreateImageAtIndex(cgImageSourceRef,0,NULL);
                    
                    CFRelease(cgImageSourceRef);
                    
                    if(_referenceImageRef == NULL)
                        NSLog(@"errror: no reference image");
                    else
                    {
                        [_mosaic mosaicImageWithSize:NSMakeSize(_imageWidth, _imageHeight) collection:_imageCollection referenceImage:_referenceImageRef tileSize:NSMakeSize(_tileWidth,_tileHeight) imageView:_imageView saveName:[referencePath lastPathComponent]];
                    }
                }
                [_progressIndicator stopAnimation:self];
            }
        }
    }
    );
}

- (IBAction)showSavePanel:(id)sender
{
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    [savePanel setTitle:@"well, of course you want to save that marvelous mosaic!"];
    [savePanel setNameFieldStringValue:@"mosaic.png"];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"png", nil]];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [savePanel orderOut:self];
            
            CGImageDestinationRef cgImageDestinationRef = CGImageDestinationCreateWithURL ((__bridge CFURLRef)savePanel.URL,
                                                                                           kUTTypePNG,
                                                                                           1,
                                                                                           NULL
                                                                                           );
            CGImageDestinationAddImage (cgImageDestinationRef,
                                        _mosaic.mosaicImage,
                                        NULL
                                        );
            CGImageDestinationFinalize(cgImageDestinationRef);
            CFRelease(cgImageDestinationRef);
            
        }
    }];
}

- (IBAction)saveImageDatabase:(id)sender
{
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:@"imagedb"];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [savePanel orderOut:self];
            
            NSMutableData *data = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
            [archiver encodeObject:_imageCollection forKey:@"imageCollection"];
            [archiver finishEncoding];
            NSString *savePath;
            //if(![[savePanel.URL.path pathExtension] isEqualToString:@"plist"])
            savePath = [savePanel.URL.path stringByAppendingPathExtension:@"plist"];
            [data writeToFile:savePanel.URL.path atomically:NO];
        }
    }];
}


- (IBAction)addReference:(id)sender
{
    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
    
    if([servers count])
    {
        NSMenu *menu = [[NSMenu alloc] init];
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"file/folder" action:@selector(addReferencePath) keyEquivalent:@""];
        [menu addItem:item];
        [menu addItem:[NSMenuItem separatorItem]];
        for (NSDictionary *serverDict in servers)
        {
            [menu addItemWithTitle:[serverDict valueForKey:SyphonServerDescriptionAppNameKey] action:@selector(addSyphonServer:) keyEquivalent:@""];
        }
        
        [menu popUpMenuPositioningItem:nil atLocation:NSZeroPoint inView:sender];
    }
    else
    {
        [self addReferencePath];
    }
}

- (IBAction)addSource:(id)sender
{
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem* folderItem = [[NSMenuItem alloc] initWithTitle:@"file/folder" action:@selector(addSourcePath) keyEquivalent:@""];
    [menu addItem:folderItem];
    NSMenuItem* plistItem = [[NSMenuItem alloc] initWithTitle:@"plist" action:@selector(addSourcePList) keyEquivalent:@""];
    [menu addItem:plistItem];
    
    [menu popUpMenuPositioningItem:nil atLocation:NSZeroPoint inView:sender];
}

- (IBAction)updateTileSize:(id)sender
{
    if(![_tilesCountField.stringValue isEqualToString:@"-"])
    {
        [_tileWidthField setIntValue:_imageWidthField.intValue/(_tilesCountField.intValue?_tilesCountField.intValue:1)];
        [_tileHeightField setIntValue:_imageHeightField.intValue/(_tilesCountField.intValue?_tilesCountField.intValue:1)];
    }
}

- (IBAction)updateTilesCount:(id)sender
{
    int newTilesCount;
    if(_tileWidthField.intValue && _tileHeightField.intValue && ((newTilesCount = _imageWidthField.intValue/_tileWidthField.intValue) == _imageHeightField.intValue/_tileHeightField.intValue))
        [_tilesCountField setIntValue:newTilesCount];
    else
        [_tilesCountField setStringValue:@"-"];
}

- (IBAction)updateCheckNeighborsState:(id)sender
{
    if(_mosaic)
        _mosaic.checkNeighborDistance = _checkNeighborDistanceField.intValue;
    if(_imageCollection)
        _imageCollection.checkNeighborDistance = _checkNeighborDistanceField.intValue;
}

- (IBAction)updateOnlyColorsState:(id)sender
{
    if(_mosaic)
        _mosaic.onlyColors = _onlyColorsCheckButton.state;
}

- (IBAction)updateMonochromeState:(id)sender
{
    if(_mosaic)
        _mosaic.monochrome = _monochromeCheckButton.state;
}

-(void)addSyphonServer:(id)sender
{
    [_referenceTokenField setObjectValue:[(NSMenuItem*)sender title]];
    
    [self setSelectedServerDescriptions:[[SyphonServerDirectory sharedDirectory] serversMatchingName:nil appName:[(NSMenuItem*)sender title]]];
    [_glView setup];
    
    [_imageView setHidden:YES];
    [_glView setHidden:NO];
}

-(void)addReferencePath
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"select your mosaic reference"];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"png", @"jpeg", @"jpg", @"bmp", @"tiff", @"gif", nil]];
    [openPanel setCanChooseDirectories:YES];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [openPanel orderOut:self];
            if(![_glView isHidden])
               [_referenceTokenField setObjectValue:nil];
            
            [_referenceTokenField setObjectValue:[[_referenceTokenField objectValue] arrayByAddingObject:openPanel.URL]];
            
            [_imageView setHidden:NO];
            [_glView setHidden:YES];
            [_glView.syClient stop];
        }
    }];
}

-(void)addSourcePath
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"select a source image/folder"];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"png", @"jpeg", @"jpg", @"bmp", @"tiff", @"gif", nil]];
    [openPanel setCanChooseDirectories:YES];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [openPanel orderOut:self];
            
            [_sourceTokenField setObjectValue:[[_sourceTokenField objectValue] arrayByAddingObject:openPanel.URL]];
            
            [_tilesCountField setEditable:YES];
            [_tileWidthField setEditable:YES];
            [_tileHeightField setEditable:YES];
            [_tilesCountField setSelectable:YES];
            [_tileWidthField setSelectable:YES];
            [_tileHeightField setSelectable:YES];
        }
    }];
}

-(void)addSourcePList
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"select a source plist"];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"plist"]];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            [openPanel orderOut:self];
            
            [_sourceTokenField setObjectValue: [NSArray arrayWithObject:openPanel.URL]];
            
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfURL:openPanel.URL]];
            self.imageCollection = [unarchiver decodeObjectForKey:@"imageCollection"];
            [unarchiver finishDecoding];
            
            [_tileWidthField setIntValue:_imageCollection.width];
            [_tileHeightField setIntValue:_imageCollection.height];
            [self updateTilesCount:nil];
            [_tilesCountField setEditable:NO];
            [_tileWidthField setEditable:NO];
            [_tileHeightField setEditable:NO];
            [_tilesCountField setSelectable:NO];
            [_tileWidthField setSelectable:NO];
            [_tileHeightField setSelectable:NO];
        }
    }];
}

- (void)loadSettings
{
    NSData *data = [NSData dataWithContentsOfFile:[[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"settings"]];
    if(data)
    {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        
        [_imageWidthField setIntegerValue:[unarchiver decodeIntegerForKey:@"imageWidth"]];
        [_imageHeightField setIntegerValue:[unarchiver decodeIntegerForKey:@"imageHeight"]];
        [_tileWidthField setIntegerValue:[unarchiver decodeIntegerForKey:@"tileWidth"]];
        [_tileHeightField setIntegerValue:[unarchiver decodeIntegerForKey:@"tileHeight"]];
        if([unarchiver decodeIntegerForKey:@"tilesCount"])
            [_tilesCountField setIntegerValue:[unarchiver decodeIntegerForKey:@"tilesCount"]];
        else
            [_tilesCountField setStringValue:@"-"];
        [_toleranceField setIntegerValue:[unarchiver decodeIntegerForKey:@"tolerance"]];
        [_checkNeighborDistanceField setIntegerValue:[unarchiver decodeIntegerForKey:@"neighborDistance"]];
        
        NSArray *tokens = [unarchiver decodeObjectForKey:@"referenceTokens"];
        for(id token in tokens)
        {
            if([token isKindOfClass:[NSURL class]])
            {
                NSError *err;
                if([(NSURL*)token checkResourceIsReachableAndReturnError:&err] == YES)
                    [_referenceTokenField setObjectValue:[[_referenceTokenField objectValue] arrayByAddingObject:token]];
            }
        }
        tokens = [unarchiver decodeObjectForKey:@"sourceTokens"];
        for(id token in tokens)
        {
            if([token isKindOfClass:[NSURL class]])
            {
                NSError *err;
                if([(NSURL*)token checkResourceIsReachableAndReturnError:&err] == YES)
                    [_sourceTokenField setObjectValue:[[_sourceTokenField objectValue] arrayByAddingObject:token]];
            }
        }
        [unarchiver finishDecoding];
        
        if([[[_sourceTokenField.objectValue objectAtIndex:0] pathExtension] isEqualToString:@"plist"])
        {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfURL:[_sourceTokenField.objectValue objectAtIndex:0]]];
            self.imageCollection = [unarchiver decodeObjectForKey:@"imageCollection"];
            [unarchiver finishDecoding];
            
            [_tileWidthField setIntValue:_imageCollection.width];
            [_tileHeightField setIntValue:_imageCollection.height];
            [self updateTilesCount:nil];
            [_tilesCountField setEditable:NO];
            [_tileWidthField setEditable:NO];
            [_tileHeightField setEditable:NO];
            [_tilesCountField setSelectable:NO];
            [_tileWidthField setSelectable:NO];
            [_tileHeightField setSelectable:NO];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *settingsArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [settingsArchiver encodeObject:_referenceTokenField.objectValue forKey:@"referenceTokens"];
    [settingsArchiver encodeObject:_sourceTokenField.objectValue forKey:@"sourceTokens"];
    
    [settingsArchiver encodeInteger:_imageWidthField.stringValue.integerValue forKey:@"imageWidth"];
    [settingsArchiver encodeInteger:_imageHeightField.stringValue.integerValue forKey:@"imageHeight"];
    [settingsArchiver encodeInteger:_tileWidthField.stringValue.integerValue forKey:@"tileWidth"];
    [settingsArchiver encodeInteger:_tileHeightField.stringValue.integerValue forKey:@"tileHeight"];
    [settingsArchiver encodeInteger:_tilesCountField.stringValue.integerValue forKey:@"tilesCount"];
    [settingsArchiver encodeInteger:_toleranceField.stringValue.integerValue forKey:@"tolerance"];
    [settingsArchiver encodeInteger:_checkNeighborDistanceField.integerValue forKey:@"neighborDistance"];
    
    [settingsArchiver finishEncoding];
    [data writeToFile:[[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"settings"] atomically:YES];
    
    
	[_glView setSyClient:nil];
    
	[syClient stop];
	syClient = nil;
}


#pragma mark Token Field Delegate

/*-(BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject
{
    return YES;
}

-(NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"token menu"];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"useless menu item" action:@selector(doSomething) keyEquivalent:@""];
    [menu addItem:item];
    return menu;
}*/

- (NSArray *)tokenField:(NSTokenField *)tokenFieldArg completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex
{
    NSMutableArray *trackNames = [NSMutableArray array];
    
    BOOL isDir;
    if([[NSFileManager defaultManager] fileExistsAtPath:[substring stringByDeletingLastPathComponent] isDirectory:&isDir] && &isDir)
    {
        [trackNames addObjectsFromArray:[[NSFileManager defaultManager] directoryContentsAtPath:[substring stringByDeletingLastPathComponent]]];
        for (int i = 0; i < trackNames.count; i++)
        {
            NSString *pathComponent = [trackNames objectAtIndex:i];
            if([pathComponent characterAtIndex:0]=='.')
                continue;
            pathComponent = [[substring stringByDeletingLastPathComponent] stringByAppendingPathComponent:pathComponent];
            [trackNames setObject:pathComponent atIndexedSubscript:i];
        }
    }

    if(tokenFieldArg == _referenceTokenField)
    {
        NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
        for (NSDictionary *serverDict in servers)
        {
            [trackNames addObject:[serverDict valueForKey:SyphonServerDescriptionAppNameKey]];
        }
    }
    NSArray *matchingTracks = [trackNames filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", substring]];
    return matchingTracks;
}

-(NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    NSMutableArray *returnTokens = [NSMutableArray array];
    for (int i = 0; i < tokens.count; i++)
    {
        id token = [tokens objectAtIndex:i];
        if([token isKindOfClass:[NSString class]])
        {
            NSURL *newToken = [[NSURL alloc] initWithString:[token stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
            [returnTokens addObject:newToken];
            
            NSLog(@"token: %@",newToken.path);
        }
    }
    
    return returnTokens;
}

-(NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
    if([representedObject isKindOfClass:[NSURL class]])
        return [(NSURL*)representedObject path].lastPathComponent;
    else if([representedObject isKindOfClass:[SyphonServer class]])
        return [(SyphonServer*)representedObject name];
    return (NSString*)representedObject;
}


#pragma mark syphon
- (void)setSelectedServerDescriptions:(NSArray *)descriptions
{
    if (![descriptions isEqualToArray:_selectedServerDescriptions])
    {
        //[descriptions retain];
        //[_selectedServerDescriptions release];
        _selectedServerDescriptions = descriptions;
        // Stop our current client
        [syClient stop];
        //[syClient release];
        // Reset our terrible FPS display
        fpsStart = [NSDate timeIntervalSinceReferenceDate];
        fpsCount = 0;
        self.FPS = 0;
        syClient = [[SyphonClient alloc] initWithServerDescription:[descriptions lastObject] options:nil newFrameHandler:^(SyphonClient *client) {
            // This gets called whenever the client receives a new frame.
            
            // The new-frame handler could be called from any thread, but because we update our UI we have
            // to do this on the main thread.
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // First we track our framerate...
                fpsCount++;
                float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
                if (elapsed > 1.0)
                {
                    self.FPS = ceilf(fpsCount / elapsed);
                    fpsStart = [NSDate timeIntervalSinceReferenceDate];
                    fpsCount = 0;
                }
                // ...then we check to see if our dimensions display or window shape needs to be updated
                SyphonImage *frame = [client newFrameImageForContext:[[_glView openGLContext] CGLContextObj]];
                
                NSSize imageSize = frame.textureSize;
                
                //[frame release];
                
                BOOL changed = NO;
                if (self.frameWidth != imageSize.width)
                {
                    changed = YES;
                    self.frameWidth = imageSize.width;
                }
                if (self.frameHeight != imageSize.height)
                {
                    changed = YES;
                    self.frameHeight = imageSize.height;
                }
                if (changed)
                {
                    [[_glView window] setContentAspectRatio:imageSize];
                    //[self resizeWindowForCurrentVideo];
                }
                // ...then mark our view as needing display, it will get the frame when it's ready to draw
                [_glView setNeedsDisplay:YES];
            }];
        }];
        
        // Our view uses the client to draw, so keep it up to date
        [_glView setSyClient:syClient];
        
        // If we have a client we do nothing - wait until it outputs a frame
        
        // Otherwise clear the view
        if (syClient == nil)
        {
            self.frameWidth = 0;
            self.frameHeight = 0;
            [_glView setNeedsDisplay:YES];
        }
    }
}

+ (NSSet *)keyPathsForValuesAffectingStatus
{
    return [NSSet setWithObjects:@"frameWidth", @"frameHeight", @"FPS", @"selectedServerDescriptions", nil];
}

@end
