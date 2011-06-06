//
//  STLPreviewGenerator.m
//  STLQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "STLPreviewGenerator.h"
#import <OpenGL/glu.h>

static void swizzleBitmap(void * data, int rowBytes, int height) {
    int top, bottom;
    void *buffer;
    void *topP;
    void *bottomP;
    void *base;
	
    top = 0;
    bottom = height - 1;
    base = data;
    buffer = malloc(rowBytes);
	
    while (top < bottom) {
        topP = (void *)((top * rowBytes) + (intptr_t)base);
        bottomP = (void *)((bottom * rowBytes) + (intptr_t)base);
		
        bcopy(topP, buffer, rowBytes);
        bcopy(bottomP, topP, rowBytes);
        bcopy(buffer, bottomP, rowBytes);
		
        ++top;
        --bottom;
    }
    free(buffer);
}

const CGFloat kRenderUpsizeFaktor=3.;

@implementation STLPreviewGenerator
@synthesize stlModel, renderSize, wireframe;

- (id)initWithSTLModel:(STLModel*)model size:(CGSize)size forThumbnail:(BOOL)forThumbnail
{
	self = [super init];
	if(self)
	{
		thumbnail = forThumbnail;
		
		if(thumbnail)
			renderSize = CGSizeMake(512.,512.);
		else
			renderSize = CGSizeMake(size.width*kRenderUpsizeFaktor,size.height*kRenderUpsizeFaktor);
		
		dimBuildPlattform = [[Vector3 alloc] initVectorWithX:100. Y:100. Z:0.];
		zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:50. Y:50. Z:0.];

		stlModel = [model retain];
		
		cameraOffset = - 2.*MAX( dimBuildPlattform.x, dimBuildPlattform.y);
		
		CGFloat objectMaxXDim = MAX(fabsf(stlModel.cornerMaximum.x), fabsf(stlModel.cornerMinimum.x));
		CGFloat objectMaxYDim = MAX(fabsf(stlModel.cornerMaximum.y), fabsf(stlModel.cornerMinimum.y));
		CGFloat objectOffset = - 2.5*MAX( objectMaxXDim, objectMaxYDim);
		cameraOffset = MIN(objectOffset, cameraOffset);
		
		rotateX = 0.;
		rotateY = -45.;
		
		self.wireframe=!stlModel.hasNormals;
	}
	return self;
}

- (void) dealloc
{
	[stlModel release];
	[dimBuildPlattform release];
	[zeroBuildPlattform release];
	[super dealloc];
}

- (CGImageRef)generatePreviewImage
//- (QTMovie*)generatePreviewMovie
{	
	CGImageRef cgImage=nil;
	
	//	NSError* error;
	//	QTMovie *movie = [[QTMovie alloc] initToWritableData:[NSMutableData data] error:&error];


	CGLPixelFormatAttribute attribs[] = // 1
	{
		kCGLPFAOffScreen,
		kCGLPFAColorSize, (CGLPixelFormatAttribute)32,
		kCGLPFADepthSize, (CGLPixelFormatAttribute)32,
		kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
		kCGLPFASupersample,
		kCGLPFASampleAlpha,
		(CGLPixelFormatAttribute)0
	} ;
	CGLPixelFormatObj pixelFormatObj;
	GLint numPixelFormats;
	CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats); // 2
	
	long bytewidth = (GLsizei)renderSize.width * 4; // Assume 4 bytes/pixel for now
	bytewidth = (bytewidth + 3) & ~3; // Align to 4 bytes
	
	/* Build bitmap context */
	void *data;
	data = malloc((GLsizei)renderSize.width * bytewidth);
	if (data == NULL) {
		return nil;
	}
	
	CGColorSpaceRef cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
	CGContextRef bitmap;
	bitmap = CGBitmapContextCreate(data, (GLsizei)renderSize.width, (GLsizei)renderSize.height, 8, bytewidth, cSpace, kCGImageAlphaNoneSkipFirst /* XRGB */);
	CFRelease(cSpace);

	CGLContextObj contextObj;
	CGLCreateContext (pixelFormatObj, NULL, &contextObj);
	CGLDestroyPixelFormat (pixelFormatObj);
	CGLSetCurrentContext (contextObj);
	
	GLsizei memColorBufferSize = (GLsizei)renderSize.width*(GLsizei)renderSize.height*(32/8)*4;
//	GLsizei memDepthBufferSize = (GLsizei)renderSize.width*(GLsizei)renderSize.height*(32/8);
//	GLsizei memAlphaBufferSize = (GLsizei)renderSize.width*(GLsizei)renderSize.height;
	GLsizei memBufferSize = memColorBufferSize;//+memDepthBufferSize+memAlphaBufferSize;
	void* memBuffer = (void *) malloc (memBufferSize);
	CGLSetOffScreen (contextObj, (GLsizei)renderSize.width, (GLsizei)renderSize.height, (GLsizei)renderSize.width * 4, memBuffer); 
		
	glViewport(0, 0, renderSize.width, renderSize.height);
	
    glMatrixMode( GL_PROJECTION );
    glLoadIdentity();
    gluPerspective( 40., renderSize.width / renderSize.height, 0.1, MAX(1000.,- 2. *cameraOffset) );
		
    // Clear the framebuffer.
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();						// Reset The View
	
	
//	for(rotateX=0.; rotateX<360.; rotateX+=45.)
	{
		if(thumbnail)
			glClearColor( 0., 1., 0., 1. );
		else
			glClearColor( 0.1, 0.1, 0.1, 1.0 );
		glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
		
		if(stlModel)
		{	
			glEnable (GL_BLEND); 
			glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			glEnable (GL_LINE_SMOOTH); 
			if(wireframe)
			{
				glColor3f(1., 1., 1.);
				glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
			}
			else
			{
				glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
				GLfloat mat_specular[] = { .8, .8, .8, 1.0 };
				GLfloat mat_shininess[] = { 60.0 };
				GLfloat mat_ambient[] = { 0.2, 0.2, 0.2, 1.0 };
				GLfloat mat_diffuse[] = { 0.2, 0.8, 0.2, 1.0 };
				
				GLfloat light_position[] = { 1., -1., 1., 0. };
				GLfloat light_ambient[] = { 0.5, 0.5, 0.5, 1.0 };
				GLfloat light_diffuse[] = { 0.2, 0.2, 0.2, 1.0 };
				
				glMaterialfv(GL_FRONT, GL_SPECULAR,  mat_specular);
				glMaterialfv(GL_FRONT, GL_SHININESS, mat_shininess);
				glMaterialfv(GL_FRONT, GL_AMBIENT,   mat_ambient);
				glMaterialfv(GL_FRONT, GL_DIFFUSE,   mat_diffuse);
				
				glLightfv(GL_LIGHT0, GL_AMBIENT,  light_ambient);
				glLightfv(GL_LIGHT0, GL_DIFFUSE,  light_diffuse);
				glLightfv(GL_LIGHT0, GL_POSITION, light_position);
				
				glEnable(GL_DEPTH_TEST);
				glEnable(GL_COLOR_MATERIAL);
				glEnable(GL_LIGHTING);
				glEnable(GL_LIGHT0);
			}

			glTranslatef(0.f,0.f,cameraOffset);
			glRotatef(rotateX, 0.f, 1.f, 0.f);
			glRotatef(rotateY, 1.f, 0.f, 0.f);
			
			glColor3f(1., 1., 1.);
			glBegin(GL_TRIANGLES);
			STLBinaryHead* stl = [stlModel stlHead];
			STLFacet* facet = firstFacet(stl);
			for(NSUInteger i = 0; i<stl->numberOfFacets; i++)
			{
				glNormal3fv((GLfloat const *)&(facet->normal));
				for(NSInteger pIndex = 0; pIndex<3; pIndex++)
				{
					//glVertex3f((GLfloat)facet->p[pIndex].x, (GLfloat)facet->p[pIndex].y, (GLfloat)facet->p[pIndex].z);
					glVertex3fv((GLfloat const *)&(facet->p[pIndex]));
				}
				facet = nextFacet(facet);
			}
			glEnd();
			
			if(!wireframe)
			{
				glDisable(GL_COLOR_MATERIAL);
				glDisable(GL_LIGHTING);
				glDisable(GL_LIGHT0);
			}
			const GLfloat platformZ = 0.;
			
			if(thumbnail)
				glColor4f(.252, .212, .122, 1.);
			else
				glColor4f(1., .749, 0., .1);
			glBegin(GL_QUADS);
			glVertex3f(-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
			glVertex3f(-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
			glEnd();
			
			glBegin(GL_LINES);
			glColor4f(1., 0., 0., .5);
			for(CGFloat x = -zeroBuildPlattform.x; x<dimBuildPlattform.x-zeroBuildPlattform.x; x+=10.)
			{
				glVertex3f(x, -zeroBuildPlattform.y, platformZ);
				glVertex3f(x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			}
			glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
			glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			
			for(CGFloat y =  -zeroBuildPlattform.y; y<dimBuildPlattform.y-zeroBuildPlattform.y; y+=10.)
			{
				glVertex3f(-zeroBuildPlattform.x, y, platformZ);
				glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, y, platformZ);
			}
			glVertex3f(-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
			glEnd();
			
			if(!wireframe)
			{
				glDisable(GL_DEPTH_TEST);
			}
			
			glDisable (GL_LINE_SMOOTH); 
			glDisable (GL_BLEND); 
		}
				
		/* Read framebuffer into our bitmap */
		glPixelStorei(GL_PACK_ALIGNMENT, (GLint)4); /* Force 4-byte alignment */
		glPixelStorei(GL_PACK_ROW_LENGTH, (GLint)0);
		glPixelStorei(GL_PACK_SKIP_ROWS, (GLint)0);
		glPixelStorei(GL_PACK_SKIP_PIXELS, (GLint)0);
		
		/* Fetch the data in XRGB format, matching the bitmap context. */
		glReadPixels((GLint)0, (GLint)0, (GLsizei)renderSize.width, (GLsizei)renderSize.width, GL_BGRA,
					 GL_UNSIGNED_INT_8_8_8_8, // for Intel! http://lists.apple.com/archives/quartz-dev/2006/May/msg00100.html
					 data);
		swizzleBitmap(data, bytewidth, (GLsizei)renderSize.height);
		
		/* Make an image out of our bitmap; does a cheap vm_copy of the bitmap */
		cgImage = CGBitmapContextCreateImage(bitmap);
//		if(cgImage)
//		{
	//		NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
	//		// Create an NSImage and add the bitmap rep to it...
	//		NSImage *image = [[NSImage alloc] init];
	//		[image addRepresentation:bitmapRep];
			
	//        [movie addImage:image forDuration:QTMakeTime(1, 10) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	//																			 @"jpeg", QTAddImageCodecType, nil]];
	//        [movie setCurrentTime:[movie duration]];
	//		[image release];
	//		[bitmapRep release];
//		}
	}
	
	/* Get rid of bitmap */
	CFRelease(bitmap);
	free(data);
	
	
	CGLSetCurrentContext (NULL);
	CGLClearDrawable (contextObj);
	CGLDestroyContext (contextObj);
	free(memBuffer);

//	[movie writeToFile:@"/Users/zaggo/Desktop/test.mov" withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:QTMovieFlatten] error:&error];
//	return [movie autorelease];

	return cgImage;
}

@end
