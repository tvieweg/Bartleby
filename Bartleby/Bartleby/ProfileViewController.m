//
//  ProfileViewController.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/20/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
//

#import "ProfileViewController.h"
#import "DataSource.h"
#import <Parse/Parse.h>

@interface ProfileViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (weak, nonatomic) IBOutlet UIButton *profilePicture;
@property (weak, nonatomic) IBOutlet UILabel *displayName;

- (IBAction)changeProfilePicture:(id)sender;

@end

@implementation ProfileViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    self.profilePicture.layer.cornerRadius = self.profilePicture.frame.size.width / 2;
    self.profilePicture.clipsToBounds = YES;
    self.displayName.text = [DataSource sharedInstance].userID.displayName;
    
    if ([DataSource sharedInstance].userProfilePicture != nil) {
        [self.profilePicture setImage:[DataSource sharedInstance].userProfilePicture forState:UIControlStateNormal];
    } else {
        [self.profilePicture setImage:[UIImage imageNamed:@"blankAccount"] forState:UIControlStateNormal]; 
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.navigationItem.title = @"Profile";
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,64)];
    [self.view addSubview:self.navBar];
    [self.navBar pushNavigationItem:self.navigationItem animated:NO];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(didPressLogout)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didPressDone)];
    
    UIColor *navigationBarColor = [UIColor whiteColor];
    UIColor *textColor = [UIColor blackColor];
    
    self.navBar.barTintColor = navigationBarColor;
    self.navBar.tintColor = textColor;
    self.navBar.titleTextAttributes = @{NSForegroundColorAttributeName : textColor};
    
    self.profilePicture.imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    _activityIndicator.center = self.view.center;
    _activityIndicator.hidesWhenStopped = YES;
    _activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    
    [self.view addSubview:_activityIndicator];
    
}

#pragma mark - button methods

- (void) didPressDone {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) didPressLogout {
    
    [[DataSource sharedInstance] saveConversationsToDisk];

    [PFUser logOut];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - helper methods

- (void) displayErrorAlertWithTitle:(NSString *)title andError:(NSString *)errorString {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:errorString
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles: nil];
    [alert show];
}

#pragma mark - profile picture changes

- (IBAction)changeProfilePicture:(id)sender {

        // Preset an action sheet which enables the user to take a new picture or select and existing one.
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"  destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
        
        // Show the action sheet
        [sheet showFromToolbar:self.navigationController.toolbar];
    }
    
#pragma mark - UIActionSheetDelegate methods

// Override this method to know if user wants to take a new photo or select from the photo library
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if (imagePicker) {
        // set the delegate and source type, and present the image picker
        imagePicker.delegate = self;
        if (0 == buttonIndex) {
            imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        }
        else if (1 == buttonIndex) {
            imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        }
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
    else {
        // Problem with camera, alert user
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Camera" message:@"Please use a camera enabled device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - UIImagePickerViewControllerDelegate

// For responding to the user tapping Cancel.
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Override this delegate method to get the image that the user has selected and send it view Multipeer Connectivity to the connected peers.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    //Start progress spinner
    [_activityIndicator startAnimating];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *newProfilePicture = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
        
        NSData *imageData = UIImagePNGRepresentation(newProfilePicture);
        PFFile *imageFile = [PFFile fileWithName:@"profile.png" data:imageData];
        
        PFUser *currentUser = [PFUser currentUser];
        currentUser[@"profilePicture"] = imageFile;
        [currentUser saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            //Start progress spinner
            [_activityIndicator stopAnimating];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];

            if (succeeded) {
                [DataSource sharedInstance].userProfilePicture = newProfilePicture;
                [self.profilePicture setImage:[DataSource sharedInstance].userProfilePicture forState:UIControlStateNormal];
            } else {
                //show user error
                NSString *errorString = [error userInfo][@"error"];   // Show the errorString somewhere and let the user try again.
                
                [self displayErrorAlertWithTitle:@"Something's wrong" andError:errorString];
            }
        }];
    });
}

@end
