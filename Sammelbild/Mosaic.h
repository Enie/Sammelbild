//
//  NSImage+Mosaic.h
//  Sammelbild
//
//  Created by Enie Weiß on 08.12.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ImageCollection, ClientGLView;

@interface Mosaic : NSObject
{
    CGContextRef _mosaicImageContext;
    unsigned char* _data;
    dispatch_queue_t queue;
}
@property (unsafe_unretained) CGImageRef mosaicImage;
@property (assign) int  checkNeighborDistance;
@property (assign) BOOL onlyColors;
@property (assign) BOOL monochrome;

-(void)mosaicImageWithSize:(NSSize)size collection:(ImageCollection *)collection referenceImage:(CGImageRef)referenceImage tileSize:(NSSize)tileSize imageView:(NSImageView*)view saveName:(NSString*)name;
-(void)mosaicImageWithSize:(NSSize)size collection:(ImageCollection *)collection referenceData:(unsigned char*)data tileSize:(NSSize)tileSize view:(ClientGLView *)view;

+(CGContextRef)newContextOfSize:(CGSize)pSize;
//CGContextRef CGContextCreateWithSize(CGSize pSize);

@end
