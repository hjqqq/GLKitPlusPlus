//
//  GLSprite.m
//  Cube Patterns 3
//
//  Created by Anton Holmberg on 2012-12-16.
//  Copyright (c) 2012 Anton Holmberg. All rights reserved.
//

#import "GPSprite.h"
#import "GPCamera.h"

typedef struct {
    GLKVector2 position;
    GLKVector2 texCoord;
} VertexAttribs;

@interface GPSprite ()

@property BOOL attribsAreDirty;
@property (nonatomic, strong) GLKTextureInfo *textureInfo;

@property GLuint vertexArray;
@property GLuint vertexBuffer;
@property VertexAttribs *attribs;

@end

@implementation GPSprite

@synthesize size = _size;

static GLKBaseEffect *SHARED_EFFECT;

+ (GLKBaseEffect *)sharedEffect {
    if(!SHARED_EFFECT) {
        SHARED_EFFECT = [[GLKBaseEffect alloc] init];
        SHARED_EFFECT.texture2d0.enabled = YES;
        SHARED_EFFECT.constantColor = GLKVector4Make(1, 1, 1, 1);
        SHARED_EFFECT.useConstantColor = YES;
        
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    return SHARED_EFFECT;
}

#pragma mark - Life / Death

- (id)initWithImage:(UIImage *)image {
    if(self = [super init]) {
        
        self.attribsAreDirty = YES;
        
        NSDictionary * options = @{GLKTextureLoaderOriginBottomLeft: [NSNumber numberWithBool:YES]};
        NSError * error;
        self.textureInfo = [GLKTextureLoader textureWithCGImage:image.CGImage options:options error:&error];
        if(error) {
            NSLog(@"error while loading texture: %@", error.localizedDescription);
        }
        else {
            if(image.size.width == image.size.height &&
               log2f(image.size.width) == roundf(log2f(image.size.width))) {
                   NSLog(@"pow of two texture");
                   glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
                   glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
               }
        }
        
        NSAssert(self.textureInfo, @"Error loading sprite texture info");
        
        self.size = image.size;
        self.imageSize = image.size;
        self.color = GLKVector4Make(1, 1, 1, 1);
        self.textureFrame = CGRectMake(0, 0, self.imageSize.width, self.imageSize.height);
        
        [self createVertexArray];
    }
    return self;
}

+ (id)spriteWithImage:(UIImage *)image {
    return [[GPSprite alloc] initWithImage:image];
}

+ (id)spriteWithImageNamed:(NSString *)imageName {
    return [[GPSprite alloc] initWithImage:[UIImage imageNamed:imageName]];
}

- (void)dealloc {
    if(self.attribs)
        free(self.attribs);
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
}

#pragma mark - Restrictions

- (void)addChild:(GPNode *)node {
    NSAssert(NO, @"Sprites are not allowed to have children");
}

#pragma mark - Properties

- (void)setSize:(CGSize)size {
    _size = size;
    self.attribsAreDirty = YES;
}

- (CGSize)size { return _size; }

#pragma mark - Convenient getter / setters

- (float)width {
    return _size.width;
}

- (float)height {
    return _size.height;
}

- (void)setWidth:(float)width {
    _size.width = width;
    self.attribsAreDirty = YES;
}

- (void)setHeight:(float)height {
    _size.height = height;
    self.attribsAreDirty = YES;
}

- (void)setFrame:(CGRect)frame {
    self.position = GLKVector3Make(frame.origin.x + frame.size.width/2,
                                   frame.origin.y + frame.size.height/2,
                                   0);
    self.size = CGSizeMake(frame.size.width,
                           frame.size.height);
}

- (CGRect)frame {
    return CGRectMake(self.position.x - self.size.width/2,
                      self.position.y - self.size.height/2,
                      self.size.width,
                      self.size.height);
}

#pragma mark - Animation support for size attribute

- (void)applyPropertiesOfNode:(GPSprite *)sprite {
    [super applyPropertiesOfNode:sprite];
    
    if([sprite isKindOfClass:[GPSprite class]]) {
        self.size = sprite.size;
    }
}

- (void)lerpUnequalPropertiesFromNode:(GPSprite *)fromSprite toNode:(GPSprite *)toSprite fraction:(float)f {
    [super lerpUnequalPropertiesFromNode:fromSprite toNode:toSprite fraction:f];
    
    if([fromSprite isKindOfClass:[GPSprite class]] && [toSprite isKindOfClass:[GPSprite class]]) {
        if(!CGSizeEqualToSize(fromSprite.size, toSprite.size))
            self.size = CGSizeMake(fromSprite.size.width + f * (toSprite.size.width - fromSprite.size.width),
                                   fromSprite.size.height + f * (toSprite.size.height - fromSprite.size.height));
    }
}

- (BOOL)propertiesAreEqualToNode:(GPSprite *)sprite {
    if(![super propertiesAreEqualToNode:sprite]) return NO;
    
    return CGSizeEqualToSize(self.size, sprite.size);
}

#pragma mark - Vertex handling

- (void)createVertexArray {
    self.attribs = calloc(4, sizeof(VertexAttribs));
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(VertexAttribs), self.attribs, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(VertexAttribs), (const GLvoid *) offsetof(VertexAttribs, position));
        
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT,GL_FALSE, sizeof(VertexAttribs), (const GLvoid *) offsetof(VertexAttribs, texCoord));
    
    glBindVertexArrayOES(0);
}

- (void)updateVertexAttributes {
    
    self.attribs[0].position = GLKVector2Make(-self.size.width/2, -self.size.height/2);
    self.attribs[1].position = GLKVector2Make(self.size.width/2, -self.size.height/2);
    self.attribs[2].position = GLKVector2Make(-self.size.width/2, self.size.height/2);
    self.attribs[3].position = GLKVector2Make(self.size.width/2, self.size.height/2);
    
    CGRect normTexCoord = CGRectMake(self.textureFrame.origin.x/self.imageSize.width,
                                  self.textureFrame.origin.y/self.imageSize.height,
                                  self.textureFrame.size.width/self.imageSize.width,
                                  self.textureFrame.size.height/self.imageSize.height);
    
    self.attribs[0].texCoord = GLKVector2Make(normTexCoord.origin.x,
                                              normTexCoord.origin.y);
    
    self.attribs[1].texCoord = GLKVector2Make(normTexCoord.origin.x + normTexCoord.size.width,
                                              normTexCoord.origin.y);
    
    self.attribs[2].texCoord = GLKVector2Make(normTexCoord.origin.x,
                                              normTexCoord.origin.y + normTexCoord.size.height);
    
    self.attribs[3].texCoord = GLKVector2Make(normTexCoord.origin.x + normTexCoord.size.width,
                                              normTexCoord.origin.y + normTexCoord.size.height);
    
    glBindVertexArrayOES(_vertexArray);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferSubData(GL_ARRAY_BUFFER, 0, 4 * sizeof(VertexAttribs), self.attribs);
    glBindVertexArrayOES(0);
    
    self.attribsAreDirty = NO;
}

#pragma mark - Draw

- (void)draw {
    
    if(self.attribsAreDirty) {
        [self updateVertexAttributes];
    }
    
    self.class.sharedEffect.transform.modelviewMatrix = self.modelViewMatrix;
    self.class.sharedEffect.transform.projectionMatrix = self.camera.projectionMatrix;
    self.class.sharedEffect.texture2d0.name = self.textureInfo.name;
    self.class.sharedEffect.constantColor = self.color;
    
    [self.class.sharedEffect prepareToDraw];
    
    glBindVertexArrayOES(_vertexArray);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArrayOES(0);
    
    self.class.sharedEffect.constantColor = GLKVector4Make(1, 1, 1, 1);
}

@end
