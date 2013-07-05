//
//  AppDelegate.h
//  Sammelbild
//
//  Created by Enie Weiß on 15.11.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuickLook/QuickLook.h>

@class ImageCollection, Mosaic, MosaicImageView, ClientGLView, SyphonClient, SettingsScrollView;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTokenFieldDelegate>
{
    SyphonClient* syClient;
    NSTimeInterval fpsStart;
	NSUInteger fpsCount;
    //IBOutlet ClientGLView* _glView;
}

@property (readwrite, retain, nonatomic) NSArray *selectedServerDescriptions;

@property (readonly) NSString *status; // "frameWidth x frameHeight : FPS" or "--" if no server
@property (assign) NSUInteger FPS;
@property (readwrite, assign) NSUInteger frameWidth;
@property (readwrite, assign) NSUInteger frameHeight;

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet MosaicImageView *imageView;
@property (weak) IBOutlet ClientGLView *glView;
@property (weak) IBOutlet NSScrollView *settingsScrollView;
@property (weak) IBOutlet NSView *settingsView;


@property (weak) IBOutlet NSTextField *tilesCountField;
@property (weak) IBOutlet NSTextField *subdivisionLevelField;
@property (weak) IBOutlet NSTextField *toleranceField;
@property (weak) IBOutlet NSTextField *imageWidthField;
@property (weak) IBOutlet NSTextField *imageHeightField;
@property (weak) IBOutlet NSTextField *tileWidthField;
@property (weak) IBOutlet NSTextField *tileHeightField;
@property (weak) IBOutlet NSButton *checkNeighborsCheckButton;
@property (weak) IBOutlet NSButton *onlyColorsCheckButton;
@property (weak) IBOutlet NSButton *monochromeCheckButton;
@property (weak) IBOutlet NSTextField *checkNeighborDistanceField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property (strong) ImageCollection *imageCollection;
@property (strong) Mosaic *mosaic;
@property (strong) NSImage *mosaicImage;
@property (assign) CGImageRef referenceImageRef;

@property (assign) int imageWidth;
@property (assign) int imageHeight;
@property (assign) int tilesCount;
@property (assign) int tileWidth;
@property (assign) int tileHeight;
@property (assign) int subdivisionLevel;
@property (strong) NSArray *references;
@property (strong) NSArray *sources;
@property (strong) NSString *destinationPath;

@property (weak) IBOutlet NSTokenField *referenceTokenField;
@property (weak) IBOutlet NSTokenField *sourceTokenField;

@property (weak) IBOutlet NSButton *addReferenceButton;
@property (weak) IBOutlet NSButton *addSourceButton;


- (IBAction)mosaicize:(id)sender;
- (IBAction)showSavePanel:(id)sender;
- (IBAction)saveImageDatabase:(id)sender;
- (IBAction)addReference:(id)sender;
- (IBAction)addSource:(id)sender;
- (IBAction)updateTileSize:(id)sender;
- (IBAction)updateTilesCount:(id)sender;
- (IBAction)updateCheckNeighborsState:(id)sender;
- (IBAction)updateOnlyColorsState:(id)sender;
- (IBAction)updateMonochromeState:(id)sender;


@end
