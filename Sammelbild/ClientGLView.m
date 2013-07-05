/*
    SimpleClientGLView.m
	Syphon (SDK)
	
    Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini).
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ClientGLView.h"
#import "Mosaic.h"
#import "AppDelegate.h"

@implementation ClientGLView

@synthesize syClient;

-(void) awakeFromNib
{	
	//const GLint on = 1;
	//[[self openGLContext] setValues:&on forParameter:NSOpenGLCPSwapInterval];
    mosaic = [[Mosaic alloc] init];
    
    const GLint on = 1;
	[[self openGLContext] setValues:&on forParameter:NSOpenGLCPSwapInterval];
    thisIsNotTheFirstFrame = NO;
}

- (void)drawRect:(NSRect)dirtyRect
{
	//[[self openGLContext] makeCurrentContext];
	
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	
	// Get a new frame from the client
	SyphonImage *image = [syClient newFrameImageForContext:cgl_ctx];
    int width = image.textureSize.width;
    int height = image.textureSize.height;
    
	if(image)
	{
        AppDelegate* delegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
        
        //CVPixelBufferRef pxbuffer = NULL;
        //CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pxbuffer);
        
        if(delegate.imageCollection)
        {
            // Save state as above, skipped for brevity
            // ...
            
            // Store previous state
            glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &prevFBO);
            glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &prevReadFBO);
            glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &prevDrawFBO);
            
            // Push attribs
            glPushAttrib(GL_ALL_ATTRIB_BITS);
            
            // The first thing we do is read data from the previous render-cycle
            // This means the GPU has had a full frame's time to perform the download to PBO
            // Skip this the first frame
            if (thisIsNotTheFirstFrame)
            {
                glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
                void *pixelData = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY);
                // Do something with the pixel data
                if(pixelData)
                    [mosaic mosaicImageWithSize:image.textureSize collection:delegate.imageCollection referenceData:pixelData tileSize:CGSizeMake(delegate.tileWidth, delegate.tileHeight) view:self];
            }
            
            thisIsNotTheFirstFrame = YES;
            
            // Now start the current frame downloading
            
            // Attach the FBO
            glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);
            glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
            
            // Set up required state
            glViewport(0, 0,  width, height);
            glMatrixMode(GL_PROJECTION);
            glPushMatrix();
            glLoadIdentity();
            
            glOrtho(0.0, width,  0.0,  height, -1, 1);
            
            glMatrixMode(GL_MODELVIEW);
            glPushMatrix();
            glLoadIdentity();
            
            // Clear
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT);
            
            // Bind the texture
            glEnable(GL_TEXTURE_RECTANGLE_ARB);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, tex);
            
            // Configure texturing as we want it
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
            
            glColor4f(1.0, 1.0, 1.0, 1.0);
            
            // Draw it
            // These coords flip the texture vertically because often you'll want to do that
            GLfloat texCoords[] =
            {
                0.0, height,
                width, height,
                width, 0.0,
                0.0, 0.0
            };
            
            GLfloat verts[] =
            {
                0.0, 0.0,
                width, 0.0,
                width, height,
                0.0, height
            };
            
            glEnableClientState( GL_TEXTURE_COORD_ARRAY );
            glTexCoordPointer(2, GL_FLOAT, 0, texCoords );
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(2, GL_FLOAT, 0, verts);
            glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
            
            // Now perform the download into the PBO
            
            glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
            glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
            
            // This is a minimal setup of pixel storage - if anything else might have touched it
            // be more explicit
            glPixelStorei(GL_PACK_ROW_LENGTH, width);
            
            // Start the download to PBO
            glGetTexImage(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid *)0);
            
            // Restore state, skipped for brevity, see set-up section
            // ...
            // Restore state we're done with thus-far
            glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
            glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, prevFBO);
            glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, prevReadFBO);
            glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, prevDrawFBO);
        }
	}
	
	// Restore OpenGL states
//	glMatrixMode(GL_MODELVIEW);
//	glPopMatrix();
//	
//	glMatrixMode(GL_PROJECTION);
//	glPopMatrix();
	
	[[self openGLContext] flushBuffer];
}

-(void)setup
{
    thisIsNotTheFirstFrame = NO;
    
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    SyphonImage *image = [syClient newFrameImageForContext:cgl_ctx];
    
    // Set-up: usually do this once and re-use these resources, however you may
    // have to recreate them if the dimensions change
    
    // Store previous state
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &prevFBO);
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &prevReadFBO);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &prevDrawFBO);
    
    // Push attribs
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
    
    // Create the texture we draw into
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, image.textureSize.width, image.textureSize.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
    
    // Create the FBO
    glGenFramebuffersEXT(1, &fbo);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);
    
    // Test that binding works
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
    GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
    if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
    {
		// Deal with this error - you won't be able to draw into the FBO
        printf("no framebuffer\n");
    }
    
    // Restore state we're done with thus-far
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, prevFBO);
    glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, prevReadFBO);
    glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, prevDrawFBO);
    
    // Save PBO state
    GLint prevPBO;
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &prevPBO);
    
    // Create our PBO and request storage for it
    glGenBuffers(1, &pbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
    glBufferData(GL_PIXEL_PACK_BUFFER, image.textureSize.width * image.textureSize.height * 4, NULL, GL_DYNAMIC_READ);
    if (glGetError() != GL_NO_ERROR)
    {
		// Storage for the PBO couldn't be allocated, deal with it here
        printf("no pixel buffer object\n");
    }
    
    // Restore state
    glBindBuffer(GL_PIXEL_PACK_BUFFER, prevPBO);
    glPopAttrib();
}


@end
