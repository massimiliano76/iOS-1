
#import "MEGAPhotoBrowserViewController.h"

#import "Helper.h"
#import "MEGAGetPreviewRequestDelegate.h"
#import "MEGAGetThumbnailRequestDelegate.h"
#import "MEGAPhotoBrowserAnimator.h"
#import "MEGAStartDownloadTransferDelegate.h"

#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"

@interface MEGAPhotoBrowserViewController () <UIScrollViewDelegate, UIViewControllerTransitioningDelegate>

@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationItem;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;

@property (nonatomic) NSMutableArray<MEGANode *> *mediaNodes;

@property (nonatomic) CGPoint panGestureInitialPoint;
@property (nonatomic, getter=isInterfaceHidden) BOOL interfaceHidden;
@property (nonatomic) NSUInteger currentIndex;

@end

@implementation MEGAPhotoBrowserViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mediaNodes = [[NSMutableArray<MEGANode *> alloc] init];
    
    for (MEGANode *node in self.nodesArray) {
        if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
            [self.mediaNodes addObject:node];
        }
    }
    
    self.panGestureInitialPoint = CGPointMake(0.0f, 0.0f);
    [self.view addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)]];
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
    
    self.scrollView.delegate = self;
    self.transitioningDelegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.view.backgroundColor = [UIColor clearColor];
    self.backgroundView.backgroundColor = [UIColor clearColor];
    self.navigationBar.layer.opacity = self.toolbar.layer.opacity = 0.0f;
    self.navigationBar.hidden = self.toolbar.hidden = self.interfaceHidden = YES;
}

#pragma mark - UI

- (void)reloadUI {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * self.mediaNodes.count, self.scrollView.frame.size.height);
    
    for (NSUInteger i = 0; i<self.mediaNodes.count; i++) {
        if (self.mediaNodes[i].handle == self.node.handle) {
            self.currentIndex = i;
            break;
        }
    }
    
    [self loadNearbyImagesFromIndex:self.currentIndex];
    [self reloadTitle];
}

- (void)reloadTitle {
    NSString *subtitle;
    if (self.mediaNodes.count == 1) {
        subtitle = AMLocalizedString(@"indexOfTotalFile", @"Singular, please do not change the placeholders as they will be replaced by numbers. e.g. 1 of 1 file.");
    } else {
        subtitle = AMLocalizedString(@"indexOfTotalFiles", @"Plural, please do not change the placeholders as they will be replaced by numbers. e.g. 1 of 3 files.");
    }
    subtitle = [subtitle stringByReplacingOccurrencesOfString:@"%1$d" withString:[NSString stringWithFormat:@"%lu", (unsigned long)self.currentIndex+1]];
    subtitle = [subtitle stringByReplacingOccurrencesOfString:@"%2$d" withString:[NSString stringWithFormat:@"%lu", (unsigned long)self.mediaNodes.count]];
    
    self.navigationItem.titleView = [Helper customNavigationBarLabelWithTitle:[self.mediaNodes objectAtIndex:self.currentIndex].name subtitle:subtitle];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    self.currentIndex = scrollView.contentOffset.x/scrollView.frame.size.width;
    [self loadNearbyImagesFromIndex:self.currentIndex];
    [self reloadTitle];
}

#pragma mark - Getting the images

- (void)loadNearbyImagesFromIndex:(NSUInteger)index {
    if (self.mediaNodes.count>0) {
        NSUInteger initialIndex = index == 0 ? 0 : index-1;
        NSUInteger finalIndex = index == self.mediaNodes.count-1 ? self.mediaNodes.count-1 : index+1;
        for (NSUInteger i = initialIndex; i<=finalIndex; i++) {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.scrollView.frame.size.width * i, 0.0f, self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            
            MEGANode *node = [self.mediaNodes objectAtIndex:i];
            
            NSString *offlineImagePath = [[Helper pathForOffline] stringByAppendingPathComponent:[self.api escapeFsIncompatible:node.name]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:offlineImagePath]) {
                imageView.image = [UIImage imageWithContentsOfFile:offlineImagePath];
            } else {
                NSString *previewPath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"previewsV3"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:previewPath]) {
                    imageView.image = [UIImage imageWithContentsOfFile:previewPath];
                } else {
                    [self setupNode:node forImageView:imageView withMode:MEGAPhotoModePreview];
                }
            }
            [self.scrollView addSubview:imageView];
            if (i==index) {
                [self.scrollView scrollRectToVisible:imageView.frame animated:NO];
            }
        }
    }
}

- (void)setupNode:(MEGANode *)node forImageView:(UIImageView *)imageView withMode:(MEGAPhotoMode)mode {
    void (^requestCompletion)(MEGARequest *request) = ^(MEGARequest *request) {
        imageView.image = [UIImage imageWithContentsOfFile:request.file];
    };
    void (^transferCompletion)(MEGATransfer *transfer) = ^(MEGATransfer *transfer) {
        imageView.image = [UIImage imageWithContentsOfFile:transfer.fileName];
    };
    
    switch (mode) {
        case MEGAPhotoModeThumbnail:
            if([node hasThumbnail]) {
                MEGAGetThumbnailRequestDelegate *delegate = [[MEGAGetThumbnailRequestDelegate alloc] initWithCompletion:requestCompletion];
                NSString *path = [Helper pathForNode:node inSharedSandboxCacheDirectory:@"thumbnailsV3"];
                [self.api getThumbnailNode:node destinationFilePath:path delegate:delegate];
            } else {
                [self setupNode:node forImageView:imageView withMode:MEGAPhotoModeFull];
            }
            
            break;
            
        case MEGAPhotoModePreview:
            if([node hasPreview]) {
                MEGAGetPreviewRequestDelegate *delegate = [[MEGAGetPreviewRequestDelegate alloc] initWithCompletion:requestCompletion];
                NSString *path = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"previewsV3"];
                [self.api getThumbnailNode:node destinationFilePath:path delegate:delegate];
            } else {
                [self setupNode:node forImageView:imageView withMode:MEGAPhotoModeFull];
            }
            
            break;
            
        case MEGAPhotoModeFull: {
            MEGAStartDownloadTransferDelegate *delegate = [[MEGAStartDownloadTransferDelegate alloc] initWithCompletion:transferCompletion];
            NSString *offlineImagePath = [[Helper pathForOffline] stringByAppendingPathComponent:[self.api escapeFsIncompatible:node.name]];
            [self.api startDownloadNode:node localPath:offlineImagePath appData:@"generate_fa" delegate:delegate];

            break;
        }
    }
}

#pragma mark - IBActions

- (IBAction)didPressCloseButton:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Gesture recognizers

- (void)panGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint touchPoint = [panGestureRecognizer translationInView:self.view];
    CGFloat verticalIncrement = touchPoint.y - self.panGestureInitialPoint.y;
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.panGestureInitialPoint = touchPoint;
            break;
            
        case UIGestureRecognizerStateChanged: {
            if (ABS(verticalIncrement) > 0) {
                self.view.frame = CGRectMake(0.0f, verticalIncrement, self.view.frame.size.width, self.view.frame.size.height);
            }
            
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (ABS(verticalIncrement) > 100.0f) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [UIView animateWithDuration:0.3 animations:^{
                    self.view.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
                }];
            }
            
            break;
        }
            
        default:
            break;
    }
}

- (void)tapGesture:(UITapGestureRecognizer *)tapGestureRecognizer {
    [UIView animateWithDuration:0.3 animations:^{
        if (self.isInterfaceHidden) {
            self.view.backgroundColor = [UIColor clearColor];
            self.backgroundView.backgroundColor = [UIColor whiteColor];
            self.navigationBar.layer.opacity = self.toolbar.layer.opacity = 1.0f;
            self.navigationBar.hidden = self.toolbar.hidden = self.interfaceHidden = NO;
        } else {
            self.view.backgroundColor = [UIColor blackColor];
            self.backgroundView.backgroundColor = [UIColor blackColor];
            self.navigationBar.layer.opacity = self.toolbar.layer.opacity = 0.0f;
            self.navigationBar.hidden = self.toolbar.hidden = self.interfaceHidden = YES;
        }
    }];
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    if (!CGRectIsEmpty(self.originFrame)) {
        return [[MEGAPhotoBrowserAnimator alloc] initWithMode:MEGAPhotoBrowserAnimatorModePresent originFrame:self.originFrame];
    } else {
        return nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    if (!CGRectIsEmpty(self.originFrame)) {
        return [[MEGAPhotoBrowserAnimator alloc] initWithMode:MEGAPhotoBrowserAnimatorModeDismiss originFrame:self.originFrame];
    } else {
        return nil;
    }
}

@end
