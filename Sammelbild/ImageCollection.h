//
//  ImageCollection.h
//  Sammelbild
//
//  Created by Enie Weiß on 15.11.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <Accelerate/Accelerate.h>

#define BUCKET_SIZE 1
#define NEIGHBOURS_TO_CHECK_FOR_DOUBLES(distance) ((distance*2+1)*(distance*2+1))

typedef struct {
    unsigned char** images;
    int lastUsedImage;
    int count;
}  imageBucket;

@interface ImageCollection : NSObject <NSCoding>
{ 
    imageBucket ***averages;
    
}
@property (strong) NSString *destinationPath;
@property (assign) CGFloat tolerance;
@property (assign) int subdivisionLevel;
@property (assign) int count;
@property (assign) int width;
@property (assign) int height;
@property (assign) int  checkNeighborDistance;
@property (assign) unsigned char ** imagesData;

-(id)initWithSource:(NSArray*)sources tileSize:(CGSize)tileSize subdivisionLevel:(int)subLevel;

+(unsigned char*)getAverageHSBColorOfData:(const unsigned char*)data width:(int)w height:(int)h;
+(unsigned char*)getAverageHSBColorOfData:(const unsigned char *)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect;
+(unsigned char*)getAverageRGBColorOfData:(const unsigned char*)data width:(int)w height:(int)h;
+(unsigned char*)getAverageRGBColorOfData:(const unsigned char *)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect;

-(unsigned char*)getTileWithImageData:(const unsigned char*)data width:(int)w height:(int)h;
-(unsigned char*)getTileWithImageData:(const unsigned char*)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect usedImages:(unsigned char**)usedImages;

@end
