//
//  ImageCollection.m
//  Sammelbild
//
//  Created by Enie Weiß on 15.11.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import "ImageCollection.h"
#import "Mosaic.h"
#import "AppDelegate.h"

#import "math.h"
#include <xmmintrin.h>

@implementation ImageCollection

-(id)initWithSource:(NSArray*)sources tileSize:(CGSize)tileSize subdivisionLevel:(int)subLevel
{
    self = [super init];
    if(self)
    {
        NSLog(@"start loading images\n");
        
        averages = (imageBucket***)calloc(256, sizeof(imageBucket**));
        for (int i = 0; i < 256; i++)
        {
            averages[i] = (imageBucket**)calloc(256, sizeof(imageBucket*));
            for (int j = 0; j < 256; j++)
            {
                averages[i][j] = (imageBucket*)calloc(256, sizeof(imageBucket));
            }
        }
        
        _width = tileSize.width;
        _height = tileSize.height;
        
        for(int i = 0; i < sources.count; i++)
        {
            NSString *path;
            if ([[sources objectAtIndex:i] isKindOfClass:[NSURL class]])
                path = [(NSURL*)[sources objectAtIndex:i] path];
            else
                path = [sources objectAtIndex:i];
            
            NSArray *dirContents = [[NSFileManager defaultManager]
                                    directoryContentsAtPath:path];
            
            _count = (int)dirContents.count;
            _imagesData = (unsigned char**)calloc(self.count, sizeof(unsigned char*));
            for (int i = 0; i < self.count; i++ ){
                _imagesData[i] = (unsigned char*) calloc(tileSize.width*tileSize.height*4, sizeof(unsigned char));
            }

            _subdivisionLevel = subLevel;
            
            //dispatch_semaphore_t fd_sema = dispatch_semaphore_create(getdtablesize() / 2);
            dispatch_semaphore_t fd_sema = dispatch_semaphore_create(3);
            //dispatch_queue_t queue = dispatch_queue_create("com.enie.sammelbild.dispatchApplyQueue", DISPATCH_QUEUE_CONCURRENT);
            
            dispatch_apply(dirContents.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                           ^(size_t i){
                               NSString* filePath = [dirContents objectAtIndex:i];
                               if ([filePath characterAtIndex:0]!='.' )
                               {
                                   NSString *sourcePath = [path stringByAppendingFormat:@"/%@",filePath];
                                   BOOL isDir;
                                   if([[NSFileManager defaultManager]
                                       fileExistsAtPath:sourcePath isDirectory:&isDir] && isDir)
                                   {
                                       NSLog(@"Is directory");
                                       _count-=1;
                                       return;
                                   }
                                   
                                   CGContextRef context = [Mosaic newContextOfSize:tileSize];
                                   //CGContextCreateWithSize(tileSize);
                                   
                                   NSURL *inputFileURL = [NSURL fileURLWithPath:sourcePath];
                                   
                                   dispatch_semaphore_wait(fd_sema, DISPATCH_TIME_FOREVER);
                                   CGImageSourceRef cgImageSourceRef = CGImageSourceCreateWithURL ((__bridge CFURLRef)inputFileURL,NULL);
                                   CGImageRef cgImageInput = CGImageSourceCreateImageAtIndex(cgImageSourceRef,0,NULL);
                                   dispatch_semaphore_signal(fd_sema);
                                   
                                   CFRelease(cgImageSourceRef);	// no longer needed
                                   
                                   CGRect rectOfOutputImage = CGRectMake(0.0, 0.0, tileSize.width, tileSize.height);
                                   
                                   //the cropping takes much too long..
                                   int imageWidth = (int)CGImageGetWidth(cgImageInput);
                                   int imageHeight = (int)CGImageGetHeight(cgImageInput);
                                   float ar = tileSize.width/tileSize.height;
                                   int cropWidth;
                                   int cropHeight;
                                   
                                   if (ar < 1) { // "tall" crop
                                       cropWidth = MIN(imageHeight * ar, imageWidth);
                                       cropHeight = cropWidth / ar;
                                   }
                                   else { // "wide" or square crop
                                       cropHeight = MIN(imageWidth / ar, imageHeight);
                                       cropWidth = cropHeight * ar;
                                   }
                                   CGImageRef scaledImage = CGImageCreateWithImageInRect(cgImageInput, CGRectMake((imageWidth-cropWidth)/2, 0, cropWidth, cropHeight));
                                   //end crop
                                   
                                   CGContextDrawImage (context,rectOfOutputImage,scaledImage);
                                   
                                   CGImageRelease (cgImageInput);	// no longer needed
                                   CGImageRelease (scaledImage);
                                   
                                   memcpy(_imagesData[i], CGBitmapContextGetData (context), tileSize.width*tileSize.height*4);
                                   
                                   unsigned char *components = [ImageCollection getAverageHSBColorOfData:_imagesData[i] width:tileSize.width height:tileSize.height];

                                   imageBucket bucket = averages[components[0]][components[1]][components[2]];
                                   
                                   addImageToBucket(_imagesData[i], &bucket);
                                   averages[components[0]][components[1]][components[2]]=bucket;
                                   
                                   NSLog(@"h%i, s%i, b%i, count:%i", components[0],components[1],components[2], bucket.count);
                                   
                                   free(components);
                                   CGContextRelease(context);
                               }
                               else
                                   _count-=1;
                           });
            free(fd_sema);
        }
    }
    NSLog(@"images loaded");
    
    return self;
}

-(unsigned char*)getTileWithImageData:(const unsigned char*)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect usedImages:(unsigned char**)usedImages
{
    unsigned char* inImageHSBComponents = [ImageCollection getAverageHSBColorOfData:data dataSize:dataSize cropRect:cropRect];
    unsigned char* tileData = [self getTileWithHSBCompnents:inImageHSBComponents usedImages:usedImages];
    free(inImageHSBComponents);
    return tileData;
}

-(unsigned char*)getTileWithImageData:(const unsigned char*)data width:(int)w height:(int)h
{
    unsigned char* inImageHSBComponents = [ImageCollection getAverageHSBColorOfData:data width:w height:h];
    unsigned char* tileData = [self getTileWithHSBCompnents:inImageHSBComponents usedImages:nil];
    free(inImageHSBComponents);
    return tileData;
}

-(unsigned char*)getImageFromBucket:(imageBucket)bucket ignore:(unsigned char**)usedImages
{
    unsigned char* outImageData = [self getImageFromBucket:bucket];
    
    if (outImageData && usedImages && !lsearch(outImageData, usedImages, NEIGHBOURS_TO_CHECK_FOR_DOUBLES(_checkNeighborDistance)))
        return outImageData;
    
    int tries = 0;
    while(lsearch(outImageData, usedImages, NEIGHBOURS_TO_CHECK_FOR_DOUBLES(_checkNeighborDistance)) && tries < bucket.count)
    {
        outImageData = [self getImageFromBucket:bucket];
        tries++;
    }
    return nil;
}

-(unsigned char*)getImageFromBucket:(imageBucket)bucket
{
    unsigned char* outImageData = nil;
    if (bucket.images) {
        outImageData = bucket.images[bucket.lastUsedImage];
        bucket.lastUsedImage = bucket.lastUsedImage+1;
        if(bucket.lastUsedImage>=bucket.count)
            bucket.lastUsedImage=0;
    }

    return outImageData;
}

-(unsigned char*)getTileWithHSBCompnents:(unsigned char*)inImageHSBComponents usedImages:(unsigned char**)usedImages
{
    unsigned char hue = inImageHSBComponents[0];
    unsigned char saturation = inImageHSBComponents[1];
    unsigned char brightness = inImageHSBComponents[2];
    
    //printf("get tile for %i, %i, %i\n", hue, saturation, brightness);
    
    imageBucket bucket = (averages[hue][saturation][brightness]);
    unsigned char* outImageData = [self getImageFromBucket:bucket ignore:usedImages];

    int huePlusTol = 0;
    int hueMinusTol = 0;
    int saturationPlusTol = 0;
    int saturationMinusTol = 0;
    
    if(!outImageData || lsearch(outImageData, usedImages, NEIGHBOURS_TO_CHECK_FOR_DOUBLES(_checkNeighborDistance)))
    {
        for (int hueTolerance = 0; hueTolerance <= _tolerance; hueTolerance++)
        {
            huePlusTol = hue+hueTolerance;
            hueMinusTol = hue-hueTolerance;
            for (int saturationTolerance = 0; saturationTolerance <= _tolerance; saturationTolerance++)
            {
                saturationPlusTol = saturation+saturationTolerance;
                saturationMinusTol = saturationMinusTol-saturationTolerance;
                for (int brightnessTolerance = 1; brightnessTolerance <= _tolerance; brightnessTolerance++)
                {
                    if (huePlusTol < 256 && saturationPlusTol < 256 && brightness+brightnessTolerance < 256)
                    {
                        bucket = (averages[huePlusTol][saturationPlusTol][brightness+brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (huePlusTol < 256 && saturationPlusTol < 256 && brightness-brightnessTolerance >= 0)
                    {
                        bucket = (averages[huePlusTol][saturationPlusTol][brightness-brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                        
                    }
                    if (huePlusTol < 256 && saturationMinusTol >= 0 && brightness+brightnessTolerance < 256)
                    {
                        bucket = (averages[huePlusTol][saturationMinusTol][brightness+brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (huePlusTol < 256 && saturationMinusTol >= 0 && brightness-brightnessTolerance >= 0)
                    {
                        bucket = (averages[huePlusTol][saturationMinusTol][brightness-brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (hueMinusTol >= 0 && saturationPlusTol < 256 && brightness+brightnessTolerance < 256)
                    {
                        bucket = (averages[hueMinusTol][saturationPlusTol][brightness+brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (hueMinusTol >= 0 && saturationPlusTol < 256 && brightness-brightnessTolerance >= 0)
                    {
                        bucket = (averages[hueMinusTol][saturationPlusTol][brightness-brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (hueMinusTol >= 0 && saturationMinusTol >= 0 && brightness+brightnessTolerance < 256)
                    {
                        bucket = (averages[hueMinusTol][saturationMinusTol][brightness+brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                    if (hueMinusTol >= 0 && saturationMinusTol >= 0 && brightness-brightnessTolerance >= 0)
                    {
                        bucket = (averages[hueMinusTol][saturationMinusTol][brightness-brightnessTolerance]);
                        if((outImageData = [self getImageFromBucket:bucket ignore:usedImages]))
                            return outImageData;
                    }
                }
            }
        }
    }
    
    return outImageData;
}

+(unsigned char *)getAverageRGBColorOfData:(const unsigned char *)data width:(int)w height:(int)h
{
    int pixelCount = w*h;
    
    int* rgbComponentsi = calloc(3, sizeof(int));
    int offset;
    
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            offset = 4*((w*round(y))+round(x));
            rgbComponentsi[0] += data[offset];
            rgbComponentsi[1] += data[offset+1];
            rgbComponentsi[2] += data[offset+2];
        }
    }
    
    unsigned char* rgbComponentsu = calloc(3, sizeof(unsigned char));
    rgbComponentsu[0] = (unsigned char)(rgbComponentsi[0]/pixelCount);
    rgbComponentsu[1] = (unsigned char)(rgbComponentsi[1]/pixelCount);
    rgbComponentsu[2] = (unsigned char)(rgbComponentsi[2]/pixelCount);
    free(rgbComponentsi);
    
    return rgbComponentsu;
}

+(unsigned char *)getAverageRGBColorOfData:(const unsigned char *)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect
{
    int pixelCount = cropRect.size.width*cropRect.size.height;
    
    int* rgbComponentsi = calloc(3, sizeof(int));
    int xOffset, yOffset; //xOffset is actually the index in an 1-dimensional array
    
    for (int y = 0; y < cropRect.size.height; y++)
    {
        yOffset = cropRect.origin.y+y;
        for (int x = 0; x < cropRect.size.width; x++)
        {
            xOffset = (dataSize.width*yOffset+x+cropRect.origin.x)*4;
            rgbComponentsi[0] += data[xOffset];
            rgbComponentsi[1] += data[xOffset+1];
            rgbComponentsi[2] += data[xOffset+2];
        }
    }
    
    unsigned char* rgbComponentsu = calloc(3, sizeof(unsigned char));
    rgbComponentsu[0] = (unsigned char)(rgbComponentsi[0]/pixelCount);
    rgbComponentsu[1] = (unsigned char)(rgbComponentsi[1]/pixelCount);
    rgbComponentsu[2] = (unsigned char)(rgbComponentsi[2]/pixelCount);
    free(rgbComponentsi);
    
    return rgbComponentsu;
}

+(unsigned char *)getAverageHSBColorOfData:(const unsigned char *)data width:(int)w height:(int)h
{
    int pixelCount = w*h;
    
    int* rgbComponents = calloc(3, sizeof(int));
    int offset;
    
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            offset = 4*((w*round(y))+round(x));
            rgbComponents[0] += data[offset];
            rgbComponents[1] += data[offset+1];
            rgbComponents[2] += data[offset+2];
        }
    }
    
    unsigned char hue = 0,saturation = 0,brighness = 0;
    
    RGBtoHSV((unsigned char)(rgbComponents[0]/pixelCount),
             (unsigned char)(rgbComponents[1]/pixelCount),
             (unsigned char)(rgbComponents[2]/pixelCount),
             &hue,
             &saturation,
             &brighness);
    
    free(rgbComponents);
    unsigned char* hsbComponents = calloc(3, sizeof(unsigned char));
    hsbComponents[0] = hue;
    hsbComponents[1] = saturation;
    hsbComponents[2] = brighness;
    
    return hsbComponents;
}

+(unsigned char *)getAverageHSBColorOfData:(const unsigned char *)data dataSize:(CGSize)dataSize cropRect:(CGRect)cropRect
{
    int pixelCount = cropRect.size.width*cropRect.size.height;
    
    int* rgbComponents = calloc(3, sizeof(int));
    int xOffset, yOffset; //xOffset is actually the index in an 1-dimensional array
    
    for (int y = 0; y < cropRect.size.height; y++)
    {
        yOffset = cropRect.origin.y+y;
        for (int x = 0; x < cropRect.size.width; x++)
        {
            xOffset = (dataSize.width*yOffset+x+cropRect.origin.x)*4;
            rgbComponents[0] += data[xOffset];
            rgbComponents[1] += data[xOffset+1];
            rgbComponents[2] += data[xOffset+2];
        }
    }
    
    unsigned char hue = 0,saturation = 0,brighness = 0;
    
    RGBtoHSV((unsigned char)(rgbComponents[0]/pixelCount),
             (unsigned char)(rgbComponents[1]/pixelCount),
             (unsigned char)(rgbComponents[2]/pixelCount),
             &hue,
             &saturation,
             &brighness);
    
    free(rgbComponents);
    unsigned char* hsbComponents = (unsigned char*)calloc(3, sizeof(unsigned char));
    hsbComponents[0] = hue;
    hsbComponents[1] = saturation;
    hsbComponents[2] = brighness;
    
    return hsbComponents;
}

void RGBtoHSV( unsigned char r, unsigned char g, unsigned char b, unsigned char *h, unsigned char *s, unsigned char *v )
{
	unsigned char min, max, delta;
	min = MIN(MIN(r,g),b);
	max = MAX(MAX(r,g),b);
	*v = max;				// v
	delta = max - min;
	if( max != 0 )
    {
		*s = 255*(long)delta/ max;
        if(*s == 0){
            *h = 0;
            return;
        }
    }
	else {
		*s = 0;
		*h = 0;
		return;
	}
    
    if(delta)
    {
        if (max == r) {
            *h = 0 + 43*(g - b)/delta;
        } else if (max == g) {
            *h = 85 + 43*(b - r)/delta;
        } else /* rgb_max == rgb.b */ {
            *h = 171 + 43*(r - g)/delta;
        }
    }
    
}

void HSVtoRGB(unsigned char h, unsigned char s, unsigned char v, unsigned char *r, unsigned char *g, unsigned char *b)
{
    if(s == 0)
    {
        *r = *g = *b = v;
        return;
    }
    
    double H = (h/255.0f)*360.0f;
    int h_i = floor(H/60);
    int f = H/60.0f - h_i;
    
    double t,p,q;
    p = v * (1-s);
    q = v * (1-s*f);
    t = v*(1-s*(1-f));
    
    switch (h_i) {
        case 0:
        case 6:
            *r=v;
            *g=t;
            *b=p;
            break;
        case 1:
            *r=q;
            *g=v;
            *b=p;
            break;
        case 2:
            *r=p;
            *g=v;
            *b=t;
            break;
        case 3:
            *r=p;
            *g=q;
            *b=v;
            break;
        case 4:
            *r=t;
            *g=p;
            *b=v;
            break;
        case 5:
            *r=v;
            *g=p;
            *b=q;
            break;
    }
    
}

BOOL lsearch(unsigned char* key, unsigned char** base, int n)
{
    if (!key || !base)
        return NO;
    
    for (int i = 0; i < n; i++)
    {
        unsigned char* k = base[i];
        if (k==key) {
            return YES;
        }
    }
    return NO;
}

void addImageToBucket(unsigned char* image, imageBucket *bucket)
{
    bucket->count++;
    unsigned char** images = (unsigned char**)calloc(bucket->count, sizeof(unsigned char*));
    for(int i = 0; i < bucket->count-1; i++)
        images[i] = bucket->images[i];
    images[bucket->count-1]=image;
    if(bucket->images)
        free(bucket->images);
    bucket->images = images;
    
}

//can't sum unsigned chars* into int[4]
void sse_sum_pixels(int* rgbComponents, const unsigned char* bits, int N)
{
    int rest = N%16; //these need to be summed after the loop
    int nb_iters = (N-rest) / 16;
    
    __m128i l;
    __m128i* r = (__m128i*)bits;
    
    for (int i = 0; i < nb_iters; ++i, ++r)
        _mm_store_si128(&l, _mm_add_epi8(l, *r));
    
    union u
    {
        __m128i m;
        unsigned char u[16];
    } x;
    
    x.m = l;
    rgbComponents[0] = x.u[0]+x.u[4]+x.u[8]+x.u[12];
    rgbComponents[1] = x.u[1]+x.u[5]+x.u[9]+x.u[13];
    rgbComponents[2] = x.u[2]+x.u[6]+x.u[10]+x.u[14];
    rgbComponents[3] = x.u[3]+x.u[7]+x.u[11]+x.u[15];
}

/*-(void)fillMedians
{
    NSLog(@"fill medians");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        int lastH=0,lastS,lastB;
        
        for(int h = 0; h < 256; h++)
        {
            lastS=0;
            for(int s = 0; s < 256; s++)
            {
                lastB = 0;
                for(int b = 0; b < 256; b++)
                {
                    if (medians[h][s][b])
                    {
                        lastH = h;
                        lastS = s;
                        lastB = b;
                    }
                    else
                        medians[h][s][b] = medians[lastH][lastS][lastB];
                }
            }
        }
        NSLog(@"filling medians done");
    });
}*/

-(void)dealloc
{
    if(_imagesData)
    {
        //TODO: huge memory leak!!
        /*for (int i = 0; i < self.count; i++){
            if(_imagesData[i])
                free(_imagesData[i]);
        }*/
        free(_imagesData);
    }
    
    if(averages)
    {
        for (int i = 0; i < 256; i++)
        {
            for (int j = 0; j < 256; j++)
            {
                for (int k= 0; k < 256; k++) {
                    if (averages[i][j][k].images) {
                        free(averages[i][j][k].images);
                    }
                }
                free(averages[i][j]);
            }
            free(averages[i]);
        }
        free(averages);
    }
}

#pragma mark - NSCoding

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        _count = [aDecoder decodeIntForKey:@"count"];
        _width = [aDecoder decodeIntForKey:@"width"];
        _height = [aDecoder decodeIntForKey:@"height"];
        
        _imagesData = (unsigned char**)calloc(_count, sizeof(unsigned char*));
        for (int i = 0; i < _count; i++ ){
            _imagesData[i] = (unsigned char*) calloc(_width*_height*4, sizeof(unsigned char));
        }
        
        NSArray *images = [aDecoder decodeObjectForKey:@"imagesData"];
        int i = 0;
        for (NSData *image in images)
        {
            unsigned char* imageData = (unsigned char*)[image bytes];
            _imagesData[i] = imageData;
            i++;
        }
        
        averages = (imageBucket***)calloc(256, sizeof(imageBucket**));
        for (int i = 0; i < 256; i++)
        {
            averages[i] = (imageBucket**)calloc(256, sizeof(imageBucket*));
            for (int j = 0; j < 256; j++)
            {
                averages[i][j] = (imageBucket*)calloc(256, sizeof(imageBucket));
            }
        }
        
        dispatch_apply(_count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),^(size_t i){
            
            unsigned char *components = [ImageCollection getAverageHSBColorOfData:_imagesData[i] width:_width height:_height];
            
            imageBucket bucket = averages[components[0]][components[1]][components[2]];
            
            addImageToBucket(_imagesData[i], &bucket);
            averages[components[0]][components[1]][components[2]]=bucket;
            
            free(components);
        });
        
        //[self fillMedians];
    }
    
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:_count forKey:@"count"];
    [aCoder encodeInt:_width forKey:@"width"];
    [aCoder encodeInt:_height forKey:@"height"];
    
    NSMutableArray* images = [NSMutableArray array];
    for (int i = 0; i < _count; i++)
    {
        NSData *imageData = [NSData dataWithBytes:_imagesData[i] length:_width*_height*4];
        [images addObject:imageData];
    }
    
    [aCoder encodeObject:[images copy] forKey:@"imagesData"];
}

@end
