

//
//  NSImage+Mosaic.m
//  Sammelbild
//
//  Created by Enie Weiß on 08.12.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import "Mosaic.h"
#import "ImageCollection.h"
#import "ClientGLView.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation Mosaic

-(void)mosaicImageWithSize:(NSSize)size collection:(ImageCollection *)collection referenceImage:(CGImageRef)referenceImage tileSize:(NSSize)tileSize imageView:(NSImageView *)view saveName:(NSString*)name
{
    //NSLog(@"create mosaic");
    
    int imageWidth = size.width;
    int imageHeight = size.height;
    int tileWidth = tileSize.width;
    int tileHeight = tileSize.height;
    int rowCount = imageHeight/tileHeight;
    int colCount = imageWidth/tileWidth;
    int tilesCount = colCount*rowCount;
    
    CGSize mosaicImageSize = CGSizeMake(imageWidth, imageHeight);
    
    /**************************   do not reuse the context!   *************************************
    //http://stackoverflow.com/questions/14071873/reusing-a-cgcontext-causing-odd-performance-losses
    ***********************************************************************************************/
    _mosaicImageContext = [Mosaic newContextOfSize:mosaicImageSize];
    
    CGContextDrawImage(_mosaicImageContext, CGRectMake(0,0,imageWidth, imageHeight), referenceImage);
    
    _data = CGBitmapContextGetData (_mosaicImageContext);
    
    BOOL fillOddRow = NO;
    BOOL fillOddCol = NO;
    
    unsigned char** usedImages;
    usedImages = (unsigned char**)calloc(tilesCount,sizeof(unsigned char*));
    BOOL * tileIsLocked = (BOOL*)calloc(tilesCount, sizeof(BOOL));
    
    if(!queue)
        queue = dispatch_queue_create("com.enie.sammelbild.dispatchApplyQueue", DISPATCH_QUEUE_CONCURRENT);
    
    
    //don't use self in blocks!!!
    BOOL block_monochrome = _monochrome;
    BOOL block_onlyColors = _onlyColors;
    int block_checkNeighborDistance = _checkNeighborDistance;
    
    for (int t = 0; t < 4; t++)
    {
        dispatch_apply(rowCount, queue,
                       ^(size_t i)
                       {
                           int row = (int)i;
                           if((fillOddRow && !(row%2)) || (!fillOddRow && (row%2)))
                               return;

                           int col = fillOddCol?1:0;
                           for (; col < colCount; col+=2)
                           {   
                               unsigned char* tileImageData;
                               
                               //boundary treatment
                               int tileOriginY = row*tileHeight;
                               int restY = (size.height-tileOriginY < tileHeight)?size.height-tileOriginY:tileHeight;
                               int tileOriginX = col*tileWidth;
                               
                               if((fillOddCol && !(col%2)) || (!fillOddCol && (col%2)))
                                   continue;
                               
                               int restX = (size.width-tileOriginX < tileWidth)?size.width-tileOriginX:tileWidth;
                               
                               CGRect tileRect = CGRectMake(tileOriginX, tileOriginY, tileWidth, tileHeight);
                               
#pragma mark - fill mosaic with images
                               
                               //fill mosaic with images
                               if (!block_onlyColors) {

                                   unsigned char** neighborImages = nil;
                                   int imageNum;
                                   //if(block_checkNeighborDistance>0)
                                   {
                                       imageNum = row*colCount+col;
                                       
                                       neighborImages = (unsigned char**)calloc(NEIGHBOURS_TO_CHECK_FOR_DOUBLES(block_checkNeighborDistance), sizeof(unsigned char*));
                                       
                                       for (int dy = -block_checkNeighborDistance; dy <= block_checkNeighborDistance; dy++)
                                       {
                                           for (int dx = -block_checkNeighborDistance; dx <= block_checkNeighborDistance; dx++)
                                           {
                                               int index = imageNum+dx+dy*colCount;
                                               if(index >= 0 && index < tilesCount)
                                                   neighborImages[(dy+block_checkNeighborDistance)*block_checkNeighborDistance + dx+block_checkNeighborDistance] = usedImages[index];
                                           }
                                       }
                                       
                                   }
                                   
                                   tileImageData = [collection getTileWithImageData:_data
                                                                           dataSize:size
                                                                           cropRect:tileRect
                                                                         usedImages:neighborImages];
                                   
                                   //if(block_checkNeighborDistance>0)
                                   {
                                       usedImages[imageNum] = tileImageData;
                                       tileIsLocked[row*colCount+col]=NO;
                                       free(neighborImages);
                                   }
                                   
                                   if(tileImageData)
                                   {
                                       int yOffset;
                                       //TODO: what happend to restY?
                                       for (int j = 0; j < restY; j++)
                                       {
                                           yOffset = tileOriginY+j;
                                           memcpy(&_data[(imageWidth*yOffset+(int)tileRect.origin.x)*4], &tileImageData[restX*j*4], restX*4);
                                       }
                                   }
                                   tileRect.origin.x = tileRect.origin.x+tileWidth;
                               }
                               
#pragma mark - fill mosaic with color
                               
                               //fill mosaic with color only
                               else
                               {
                                   unsigned char* color = [ImageCollection getAverageRGBColorOfData:_data
                                                                                           dataSize:size
                                                                                           cropRect:tileRect];
                                   
                                   unsigned char *rgba = calloc(4, sizeof(unsigned char));
                                   unsigned char *rgba_highlight = calloc(4, sizeof(unsigned char));
                                   unsigned char *rgba_background = calloc(4, sizeof(unsigned char));
                                   rgba[0] = color[0];
                                   rgba[1] = color[1];
                                   rgba[2] = color[2];
                                   rgba_highlight[0] = color[0]+50>255?255:rgba[0]+50;
                                   rgba_highlight[1] = color[1]+50>255?255:rgba[1]+50;
                                   rgba_highlight[2] = color[2]+50>255?255:rgba[2 ]+50;
                                   
                                   int32_t colorInt = *((int32_t*) rgba);
                                   int32_t highlightInt = *((int32_t*) rgba_highlight);
                                   int32_t backgroundInt = *((int32_t*) rgba_background);
                                   int32_t* intData = ((int32_t*) _data);
                                   
                                   int yOffset;
                                   for (int j = 0; j < restY; j++)
                                   {
                                       yOffset = tileOriginY+j;
                                       if(block_monochrome)
                                       {
                                            if (!j || yOffset==imageHeight-1)
                                               memset(&(intData[(imageWidth*yOffset+(int)tileRect.origin.x)]), backgroundInt, restX*4);
                                           else if(j==1)
                                               memset(&(intData[(imageWidth*yOffset+(int)tileRect.origin.x)]), highlightInt, restX*4);
                                           else
                                               memset(&(intData[(imageWidth*yOffset+(int)tileRect.origin.x)]), colorInt, restX*4);
                                       }
                                       else
                                       {
                                           if (!j || yOffset==imageHeight-1)
                                               memset_pattern4(&(((char*)_data)[(imageWidth*yOffset+(int)tileRect.origin.x)*4]), &backgroundInt, restX*4);
                                           else if(j==1)
                                               memset_pattern4(&(((char*)_data)[(imageWidth*yOffset+(int)tileRect.origin.x)*4]), &highlightInt, restX*4);
                                           else
                                               memset_pattern4(&(((char*)_data)[(imageWidth*yOffset+(int)tileRect.origin.x)*4]), &colorInt, restX*4);
                                       }
                                   
                                       memset(&(intData[(imageWidth*yOffset+(int)tileRect.origin.x)]), backgroundInt, 4);
                                       memset(&(intData[(imageWidth*yOffset+imageWidth)]), backgroundInt, 4);
                                   }
                                   
                                   tileRect.origin.x = tileRect.origin.x+tileWidth;
                                   
                                   free(rgba);
                                   free(rgba_highlight);
                                   free(rgba_background);
                               }
                           }
                       });
        
        fillOddCol=!fillOddCol;
        if(t == 1)
            fillOddRow=!fillOddRow;
    }
    
    _mosaicImage = CGBitmapContextCreateImage (_mosaicImageContext);
    CGContextRelease(_mosaicImageContext);
    
    //*
    if(view.image)
    {
        [view.image lockFocus];
        [[[NSImage alloc] initWithCGImage:_mosaicImage size:size] drawInRect:NSMakeRect(0, 0, size.width, size.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [view.image unlockFocus];
        [view setNeedsDisplay];
    }
    else
        view.image = [[NSImage alloc] initWithCGImage:_mosaicImage size:size];
    /*/
    NSImage *newImage = [[NSImage alloc] initWithCGImage:_mosaicImage size:size];
    view.image = nil;
    view.image = newImage;
    //*/
    
    NSLog(@"mosaic done");
    
    if(name && collection.destinationPath)
        [self saveImageRef:_mosaicImage path:name collection:collection];
    
    CGImageRelease(_mosaicImage);
    free(usedImages);
}


/*
 this was meant for syphon. the code needs update, its not doing the same as the mosaic method above.
 */
-(void)mosaicImageWithSize:(NSSize)size collection:(ImageCollection *)collection referenceData:(unsigned char*)data tileSize:(NSSize)tileSize view:(ClientGLView *)view
{
    if(!collection)
        return;
    
    int imageWidth = size.width;
    int imageHeight = size.height;
    int tileWidth = tileSize.width;
    int tileHeight = tileSize.height;
    int rowCount = imageHeight/tileHeight;
    int colCount = imageWidth/tileWidth;
    int tilesCount = colCount*rowCount;
    
    BOOL fillOddRow = NO;
    BOOL fillOddCol = NO;
    
    unsigned char** usedImages;
    usedImages = (unsigned char**)calloc(tilesCount,sizeof(unsigned char*));
    
    if(!queue)
        queue = dispatch_queue_create("com.enie.sammelbild.dispatchApplyQueue", DISPATCH_QUEUE_CONCURRENT);
    
    for (int t = 0; t < 4; t++)
    {
        dispatch_apply(rowCount, queue,
                       ^(size_t i)
                       {
                           int row = (int)i;//floor((float)i*(1.0/((float)imageWidth/(float)tileWidth)));
                           if((fillOddRow && !(row%2)) || (!fillOddRow && (row%2)))
                               return;
                           
                           int col = fillOddCol?1:0;
                           for (; col < colCount; col+=2)
                           {
                               unsigned char* tileImageData;
                               
                               //boundary treatment
                               int tileOriginY = row*tileHeight;
                               int restY = (size.height-tileOriginY < tileHeight)?size.height-tileOriginY:tileHeight;
                               int tileOriginX = col*tileWidth;//((i*(int)tileWidth)%(int)size.width);//-row*(tileWidth-((int)size.width%tileWidth));
                               //int col = tileOriginX/tileWidth;
                               if((fillOddCol && !(col%2)) || (!fillOddCol && (col%2)))
                                   continue;
                               int restX = (size.width-tileOriginX < tileWidth)?size.width-tileOriginX:tileWidth;
                               
                               CGRect tileRect = CGRectMake(tileOriginX, tileOriginY, tileWidth, tileHeight);
                               
                               unsigned char** neighborImages = nil;
                               int imageNum = 0;
                               if(_checkNeighborDistance>0)
                               {
                                   neighborImages = calloc(8, sizeof(unsigned char*));
                                   
                                   imageNum = row*colCount+col;
                                   
                                   neighborImages[0] = usedImages[imageNum-1>=0?i-1:imageNum];
                                   neighborImages[1] = usedImages[imageNum+1<tilesCount?imageNum+1:imageNum];
                                   neighborImages[2] = usedImages[imageNum-colCount>=0?imageNum-colCount:imageNum];
                                   neighborImages[3] = usedImages[imageNum+colCount<tilesCount?imageNum+colCount:imageNum];
                                   neighborImages[4] = usedImages[imageNum-colCount-1>=0?imageNum-colCount-1:imageNum];
                                   neighborImages[5] = usedImages[imageNum-colCount+1>=0?imageNum-colCount+1:imageNum];
                                   neighborImages[6] = usedImages[imageNum+colCount-1<tilesCount?imageNum+colCount-1:imageNum];
                                   neighborImages[7] = usedImages[imageNum+colCount+1<tilesCount?imageNum+colCount+1:imageNum];
                               }
                                   
                               tileImageData = [collection getTileWithImageData:data
                                                                       dataSize:size
                                                                       cropRect:tileRect
                                                                     usedImages:neighborImages];
                               
                               usedImages[imageNum] = tileImageData;
                               
                               free(neighborImages);
                               
                               if(tileImageData)
                               {
                                   int yOffset;
                                   for (int j = 0; j < restY; j++)
                                   {
                                       yOffset = tileOriginY+j;
                                       memcpy(&data[(imageWidth*yOffset+(int)tileRect.origin.x)*4], &tileImageData[restX*j*4], restX*4);
                                   }
                               }
                               tileRect.origin.x = tileRect.origin.x+tileWidth;
                           }
                       });
        
        fillOddCol=!fillOddCol;
        if(t == 1)
            fillOddRow=!fillOddRow;
    }
}

//CG_INLINE CGContextRef CGContextCreateWithSize(CGSize pSize)
+(CGContextRef)newContextOfSize:(CGSize)pSize
{
	
	//CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);//faster than createDeviceRGB? http://benoitgirard.wordpress.com/2010/03/09/optimizing-cgcontextdrawimage/
    
	CGContextRef bitmapContextRef = CGBitmapContextCreate (NULL,
															pSize.width,
															pSize.height,
															8,
															pSize.width * 4,
															colorSpace,
                                                            kCGImageAlphaNoneSkipLast
															);
    
    CGColorSpaceRelease(colorSpace);
    CGContextSetAllowsAntialiasing(bitmapContextRef, NO);
    CGContextSetInterpolationQuality(bitmapContextRef, kCGInterpolationNone);
    
	return bitmapContextRef;
	
}

-(void)saveImageRef:(CGImageRef)image path:(NSString*)path collection:(ImageCollection*)collection
{
    BOOL exists=NO;
    BOOL isDir=NO;
    
    NSString *savePath;
    
    if(collection.destinationPath.length)
    {
        exists = [[NSFileManager defaultManager] fileExistsAtPath:collection.destinationPath isDirectory:&isDir];
        if(exists && !isDir)
            savePath = [collection.destinationPath stringByDeletingLastPathComponent];
        else if(exists && isDir)
            savePath = collection.destinationPath;
        
        savePath = [[savePath stringByAppendingPathComponent:@"Sammelbild"] stringByAppendingPathComponent:path];
    }

    exists = [[NSFileManager defaultManager] fileExistsAtPath:[savePath stringByDeletingLastPathComponent]];
    if(!exists)
    {   
        NSError *error = nil;
        [[NSFileManager defaultManager]
                        createDirectoryAtPath:[savePath stringByDeletingLastPathComponent]
                        withIntermediateDirectories:YES
                        attributes:nil
                        error:&error];
        NSLog(@"%@", [error userInfo]);
    }
    
    NSURL * outputURL = [NSURL fileURLWithPath:savePath];
    CGImageDestinationRef cgImageDestinationRef = CGImageDestinationCreateWithURL ((__bridge CFURLRef)outputURL,
                                                                                   kUTTypeJPEG,
                                                                                   1,
                                                                                   NULL
                                                                                   );
    CGImageDestinationAddImage (cgImageDestinationRef,
                                image,
                                NULL
                                );
    CGImageDestinationFinalize(cgImageDestinationRef);
    
    CFRelease(cgImageDestinationRef);
    outputURL = nil;

    path = nil;
}

-(void)dealloc
{
    dispatch_release(queue);
}

@end
