//
//  ELCImagePickerController.m
//  ELCImagePickerDemo
//
//  Created by ELC on 9/9/10.
//  Copyright 2010 ELC Technologies. All rights reserved.
//

#import "ELCImagePickerController.h"
#import "ELCAsset.h"
#import "ELCAssetCell.h"
#import "ELCAssetTablePicker.h"
#import "ELCAlbumPickerController.h"
#import <CoreLocation/CoreLocation.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "ELCConsole.h"
#import <Photos/PHImageManager.h>

NSString const * ELCImagePickerControllerVideoDataKey = @"ELCImagePickerControllerVideoDataKey";

@implementation ELCImagePickerController

//Using auto synthesizers

- (id)initImagePicker
{
    ELCAlbumPickerController *albumPicker = [[ELCAlbumPickerController alloc] initWithStyle:UITableViewStylePlain];
    
    self = [super initWithRootViewController:albumPicker];
    if (self) {
        self.maximumImagesCount = 4;
        self.returnsImage = YES;
        self.returnsOriginalImage = YES;
        [albumPicker setParent:self];
        self.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{

    self = [super initWithRootViewController:rootViewController];
    if (self) {
        self.maximumImagesCount = 4;
        self.returnsImage = YES;
    }
    return self;
}

- (ELCAlbumPickerController *)albumPicker
{
    return self.viewControllers[0];
}

- (void)setMediaTypes:(NSArray *)mediaTypes
{
    self.albumPicker.mediaTypes = mediaTypes;
}

- (NSArray *)mediaTypes
{
    return self.albumPicker.mediaTypes;
}

- (void)cancelImagePicker
{
	if ([_imagePickerDelegate respondsToSelector:@selector(elcImagePickerControllerDidCancel:)]) {
		[_imagePickerDelegate performSelector:@selector(elcImagePickerControllerDidCancel:) withObject:self];
	}
}

- (BOOL)shouldSelectAsset:(ELCAsset *)asset previousCount:(NSUInteger)previousCount
{
    BOOL shouldSelect = previousCount < self.maximumImagesCount;
    if (!shouldSelect) {
        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Only %d photos please!", nil), self.maximumImagesCount];
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"You can only send %d photos at a time.", nil), self.maximumImagesCount];
        [self showAlertWithTitle:title
                                      message:message
                                 cancelButton:NSLocalizedString(@"Okay", nil)
                               fromController:self];
    }
    return shouldSelect;
}

- (BOOL)shouldDeselectAsset:(ELCAsset *)asset previousCount:(NSUInteger)previousCount;
{
    return YES;
}

- (void)selectedAssets:(NSArray *)assets
{
	NSMutableArray *returnArray = [[NSMutableArray alloc] init];
	
    NSUInteger __block assetsLoaded = 0;
    NSUInteger __block assetsToLoad = assets.count;
	for(ELCAsset *elcasset in assets) {
        PHAsset *asset = elcasset.asset;
        PHAssetMediaType type = asset.mediaType;
        
		NSMutableDictionary *workingDictionary = [[NSMutableDictionary alloc] init];
		
		CLLocation* wgs84Location = asset.location;
		if (wgs84Location) {
			[workingDictionary setObject:wgs84Location forKey:@"Location"];
		}
        
        [workingDictionary setObject:@(type) forKey:UIImagePickerControllerMediaType];

        //This method returns nil for assets from a shared photo stream that are not yet available locally. If the asset becomes available in the future, an ALAssetsLibraryChangedNotification notification is posted.
        if (asset.mediaType == PHAssetMediaTypeVideo) {
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.networkAccessAllowed = NO;
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                NSData *data = [NSData dataWithContentsOfURL:((AVURLAsset*)asset).URL];
                [workingDictionary setObject:data forKey:ELCImagePickerControllerVideoDataKey];
                [returnArray addObject:workingDictionary];
                assetsLoaded ++;
                if (assetsLoaded == assetsToLoad) {
                    [self notifyPickerCompleteWithArray:returnArray];
                }
            }];
        } else {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.synchronous = YES;
            options.networkAccessAllowed = NO;
            [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                if (result != nil) {
                    [workingDictionary setObject:result forKey:UIImagePickerControllerOriginalImage];
                }
                [returnArray addObject:workingDictionary];
                assetsLoaded ++;
                if (assetsLoaded == assetsToLoad) {
                    [self notifyPickerCompleteWithArray:returnArray];
                }
            }];
        }
		
	}
}

- (void)notifyPickerCompleteWithArray:(NSArray*)assets {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_imagePickerDelegate != nil && [_imagePickerDelegate respondsToSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:)]) {
            [_imagePickerDelegate performSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:) withObject:self withObject:assets];
        } else {
            [self popToRootViewControllerAnimated:NO];
        }
    });
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

- (BOOL)onOrder
{
    return [[ELCConsole mainConsole] onOrder];
}

- (void)setOnOrder:(BOOL)onOrder
{
    [[ELCConsole mainConsole] setOnOrder:onOrder];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message cancelButton:(NSString *)cancel fromController:(UIViewController*)controller {
    UIAlertController* alertView = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    if (cancel.length > 0) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:nil];
        [alertView addAction:cancelAction];
    }
    self.popoverPresentationController.sourceView = controller.view;
    self.popoverPresentationController.sourceRect = controller.view.frame;
    self.popoverPresentationController.permittedArrowDirections = 0;
    [controller presentViewController:self animated:YES completion:nil];
}

@end
