//
//  ChatViewController.m
//  Bartleby
//
//  Created by Trevor Vieweg on 7/11/15.
//  Copyright (c) 2015 Trevor Vieweg. All rights reserved.
///

@import MultipeerConnectivity;

#import "ChatViewController.h"
#import "SessionContainer.h"
#import "Transcript.h"
#import "MessageView.h"
#import "ImageView.h"
#import "ProgressView.h"
#import "DataSource.h"

@interface ChatViewController () <UITextFieldDelegate, SessionContainerDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

// Display name for conversation
@property (copy, nonatomic) NSString *displayName;
// MC Session for managing peer state and send/receive data between peers
@property (retain, nonatomic) SessionContainer *sessionContainer;
// TableView Data source for managing sent/received messagesz
@property (retain, nonatomic) NSMutableArray *transcripts;
// Map of resource names to transcripts array index
@property (retain, nonatomic) NSMutableDictionary *imageNameIndex;
// Text field used for typing text messages to send to peers
@property (retain, nonatomic) IBOutlet UITextField *messageComposeTextField;
// Button for executing the message send.
@property (retain, nonatomic) IBOutlet UIBarButtonItem *sendMessageButton;
// Button to add photos.
@property (weak, nonatomic) IBOutlet UIBarButtonItem *photoButton;
//hide keyboard when user touches outside view.
@property (weak, nonatomic) UIGestureRecognizer *hideKeyboardTapGestureRecognizer;

@end

@implementation ChatViewController

#pragma mark - Override super class methods

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Init transcripts array to use as table view data source
    _imageNameIndex = [NSMutableDictionary new];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addPeers)];
    
    //If this is a new conversation, show the peer view browser once loaded.
    if ([DataSource sharedInstance].isNewConversation) {
        [DataSource sharedInstance].isNewConversation = NO;
        [self performSegueWithIdentifier:@"showPeerBrowser" sender:self];
    }
    
    //Gesture Recognizer
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    self.hideKeyboardTapGestureRecognizer = tap;
    [self.hideKeyboardTapGestureRecognizer addTarget:self action:@selector(tapGestureDidFire:)];
    [self.view addGestureRecognizer:tap];
    
    self.tableView.backgroundColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:120/255.0 alpha:1.0];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _transcripts = [NSMutableArray new];
    
    // Listen for will show/hide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    //Load the session container for this conversation and set the delegate.
    self.sessionContainer = [DataSource sharedInstance].currentConversation;
    self.sessionContainer.delegate = self;
    self.transcripts = self.sessionContainer.sessionTranscripts;
    
    [self updateViewTitle];
    [self.tableView reloadData];
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    if (self.sessionContainer.session.connectedPeers.count == 0 && self.sessionContainer.peersConnectedToSession.count > 0) {
        
        //People were previously connected and now are not. Alert user.
        NSString *message = NSLocalizedString(@"Looks like all users have been disconnected. Reconnect using the + button above.", @"Reconnect with users description");
        Transcript *lastMessage = [self.transcripts lastObject];
        
        if (![lastMessage.message isEqualToString:message]) {
            // Send the message
            Transcript *transcript = [[Transcript alloc] initWithPeerID:[DataSource sharedInstance].userID message:message direction:TRANSCRIPT_DIRECTION_LOCAL];
            
            // Add the transcript to the table view data source and reload
            [self insertTranscript:transcript];
            
        }
    }
}

- (void) viewWillLayoutSubviews {
    
    float messageFieldWidth = self.navigationController.navigationBar.frame.size.width - self.sendMessageButton.width - self.photoButton.width - 110;
    
    self.messageComposeTextField.frame = CGRectMake(self.messageComposeTextField.frame.origin.x, self.messageComposeTextField.frame.origin.y, messageFieldWidth, self.messageComposeTextField.frame.size.height);

}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Stop listening for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    //Remove delegate and add transcripts to the session container.
    self.sessionContainer.delegate = nil;
    [DataSource sharedInstance].currentConversation.sessionTranscripts = self.transcripts;
    
    //Close keyboard before segue
    [self textFieldDidEndEditing:self.messageComposeTextField];

}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator]; 
    NSString *messageText = self.messageComposeTextField.text;
    
    [self.messageComposeTextField resignFirstResponder];
    
    self.messageComposeTextField.text = messageText;
}

#pragma mark - TapGestureRecognizer

- (void)tapGestureDidFire:(UITapGestureRecognizer *)sender {
    [self.messageComposeTextField resignFirstResponder];
    
}


#pragma mark - SessionContainerDelegate

- (void)receivedTranscript:(Transcript *)transcript
{
    // Add to table view data source and update on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
		[self insertTranscript:transcript];
    });
    
}

- (void)updateTranscript:(Transcript *)transcript
{
    // Find the data source index of the progress transcript
    NSNumber *index = [_imageNameIndex objectForKey:transcript.imageName];
    NSUInteger idx = [index unsignedLongValue];
    // Replace the progress transcript with the image transcript
    [_transcripts replaceObjectAtIndex:idx withObject:transcript];

    // Reload this particular table view row on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:idx inSection:0];
        [self.tableView reloadRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    });
}

- (void)session:(SessionContainer *)session peerDidConnect:(MCPeerID *)peer {
    //Update conversation view once peer is connected.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateViewTitle];
    });
}

#pragma mark - private methods

// Helper method for inserting a sent/received message into the data source and reload the view.
// Make sure you call this on the main thread
- (void)insertTranscript:(Transcript *)transcript
{
    // Add transcript to the data source
    [_transcripts addObject:transcript];

    // If this is a progress transcript add it's index to the map with image name as the key
    if (nil != transcript.progress) {
        NSNumber *transcriptIndex = [NSNumber numberWithUnsignedLong:(_transcripts.count - 1)];
        [_imageNameIndex setObject:transcriptIndex forKey:transcript.imageName];
    }

    // Update the table view
    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:([self.transcripts count] - 1) inSection:0];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];

    // Scroll to the bottom so we focus on the latest message
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    if (numberOfRows) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(numberOfRows - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void) updateViewTitle {
    self.displayName = [DataSource sharedInstance].currentConversation.displayName;
    
    if ([self.displayName isEqualToString:[DataSource sharedInstance].userID.displayName]) {
        //This is a new conversation with no added peers.
        self.title = @"New Conversation";
    } else {
        //This is an existing conversation
        self.title = self.displayName;
        [self.navigationController.navigationBar reloadInputViews];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// The numer of rows is based on the count in the transcripts arrays
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.transcripts.count;
}

// The individual cells depend on the type of Transcript at a given row.  We have 3 row types (i.e. 3 custom cells) for text string messages, resource transfer progress, and completed image resources
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get the transcript for this row
    Transcript *transcript = [self.transcripts objectAtIndex:indexPath.row];

    // Check if it's an image progress, completed image, or text message
    UITableViewCell *cell;
    if (nil != transcript.imageUrl) {
        // It's a completed image
        cell = [tableView dequeueReusableCellWithIdentifier:@"Image Cell" forIndexPath:indexPath];
        // Get the image view
        ImageView *imageView = (ImageView *)[cell viewWithTag:IMAGE_VIEW_TAG];
        // Set up the image view for this transcript
        imageView.transcript = transcript;
    }
    else if (nil != transcript.progress) {
        // It's a resource transfer in progress
        cell = [tableView dequeueReusableCellWithIdentifier:@"Progress Cell" forIndexPath:indexPath];
        ProgressView *progressView = (ProgressView *)[cell viewWithTag:PROGRESS_VIEW_TAG];
        // Set up the progress view for this transcript
        progressView.transcript = transcript;
    }
    else {
        // Get the associated cell type for messages
        cell = [tableView dequeueReusableCellWithIdentifier:@"Message Cell" forIndexPath:indexPath];
        // Get the message view
        MessageView *messageView = (MessageView *)[cell viewWithTag:MESSAGE_VIEW_TAG];
        // Set up the message view for this transcript
        messageView.transcript = transcript;
    }
    
    cell.backgroundColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:120/255.0 alpha:1.0];
    
    return cell;
}

// Return the height of the row based on the type of transfer and custom view it contains
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dynamically compute the label size based on cell type (image, image progress, or text message)
    Transcript *transcript = [self.transcripts objectAtIndex:indexPath.row];
    if (nil != transcript.imageUrl) {
        return [ImageView viewHeightForTranscript:transcript];
    }
    else if (nil != transcript.progress) {
        return [ProgressView viewHeightForTranscript:transcript];
    }
    else {
        return [MessageView viewHeightForTranscript:transcript];
    }
}

#pragma mark - IBAction methods

// Action method when user presses "send"
- (IBAction)sendMessageTapped:(id)sender
{    
    // Dismiss the keyboard.  Message will be actually sent when the keyboard resigns.
    [self.messageComposeTextField resignFirstResponder];
}

// Action method when user presses the "camera" photo icon.
- (IBAction)photoButtonTapped:(id)sender
{
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

    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];

        // Save the new image to the documents directory
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, 1.0);

        // Create a unique file name
        NSDateFormatter *inFormat = [NSDateFormatter new];
        [inFormat setDateFormat:@"yyMMdd-HHmmss"];
        NSString *imageName = [NSString stringWithFormat:@"image-%@.JPG", [inFormat stringFromDate:[NSDate date]]];
        // Create a file path to our documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:imageName];
        [pngData writeToFile:filePath atomically:YES]; // Write the file
        // Get a URL for this file resource
        NSURL *imageUrl = [NSURL fileURLWithPath:filePath];

        // Send the resource to the remote peers and get the resulting progress transcript
        Transcript *transcript = [self.sessionContainer sendImage:imageUrl];

        // Add the transcript to the data source and reload
        dispatch_async(dispatch_get_main_queue(), ^{
            [self insertTranscript:transcript];
        });
    });
}

#pragma mark - UITextFieldDelegate methods

// Override to dynamically enable/disable the send button based on user typing
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger length = self.messageComposeTextField.text.length - range.length + string.length;
    if (length > 0) {
        self.sendMessageButton.enabled = YES;
    }
    else {
        self.sendMessageButton.enabled = NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField endEditing:YES];
    return YES;
}

// Delegate method called when the message text field is resigned. 
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    // Check if there is any message to send
    if (self.messageComposeTextField.text.length) {
        // Resign the keyboard
        [textField resignFirstResponder];
        
        // Send the message
        Transcript *transcript = [self.sessionContainer sendMessage:self.messageComposeTextField.text];

        if (transcript) {
            // Add the transcript to the table view data source and reload
            [self insertTranscript:transcript];
        }
        
        // Clear the textField and disable the send button
        self.messageComposeTextField.text = @"";
        self.sendMessageButton.enabled = NO;
    }
}

#pragma mark - Toolbar animation helpers

// Helper method for moving the toolbar frame based on user action
- (void)moveToolBarUp:(BOOL)up forKeyboardNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];

    // Get animation info from userInfo
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardFrame;
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];

    // Animate up or down
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];

    [self.navigationController.toolbar setFrame:CGRectMake(self.navigationController.toolbar.frame.origin.x, self.navigationController.toolbar.frame.origin.y + (keyboardFrame.size.height * (up ? -1 : 1)), self.navigationController.toolbar.frame.size.width, self.navigationController.toolbar.frame.size.height)];
    
    [self.tableView setFrame:CGRectMake(self.tableView.frame.origin.x, self.tableView.frame.origin.y, self.tableView.frame.size.width, self.tableView.frame.size.height + (keyboardFrame.size.height * (up ? -1 : 1)))];
    
    // Scroll to the bottom so we focus on the latest message
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    if (numberOfRows) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(numberOfRows - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }

    [UIView commitAnimations];
    
}

- (void)keyboardWillShow:(NSNotification *)notification {
    // move the toolbar frame up as keyboard animates into view
    [self moveToolBarUp:YES forKeyboardNotification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    // move the toolbar frame down as keyboard animates into view
    [self moveToolBarUp:NO forKeyboardNotification:notification];
}

#pragma mark - addPeers

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {    
    [self addPeers];
}

- (void) addPeers {
    [self performSegueWithIdentifier:@"showPeerBrowser" sender:self];
}

@end
