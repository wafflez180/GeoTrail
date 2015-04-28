//
//  ContactsTableTableViewController.m
//  SnapTrail
//
//  Created by Arthur Araujo on 4/26/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "ContactsTableTableViewController.h"
#import <Parse/Parse.h>

@interface ContactsTableTableViewController ()

@end

@implementation ContactsTableTableViewController{
    NSArray *contactsArray;
    IBOutlet UITableView *tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    //LOAD ALL THE CONTACTS
    [self loadContacts];
}

-(void)loadContacts{
    PFQuery *query = [PFQuery queryWithClassName:@"_User"];
    [query whereKey:@"username" equalTo:[[PFUser currentUser] username]]; // "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
    [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK", nil];
        }else{
            for (NSInteger i = 0; i < PFObjects.count; i++) {
                PFObject *thePostedPicture = PFObjects[i];
                NSArray *contacts = [thePostedPicture objectForKey:@"Contacts"];
                
                contactsArray = contacts;
            }
        }
        [self.tableView reloadData];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)AddNewContacts:(id)sender {
    UIAlertController *enterContactAlert = [UIAlertController alertControllerWithTitle:@"Add Contact" message:@"Please enter a username" preferredStyle:UIAlertControllerStyleAlert];
    
    [enterContactAlert addTextFieldWithConfigurationHandler:^(UITextField *textField){
        textField.placeholder = @"Username";
    }];
    [enterContactAlert addAction:[UIAlertAction actionWithTitle:@"Enter" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSArray *textFields = enterContactAlert.textFields;
        UITextField *userNameTextField = textFields[0];
        NSString *username = userNameTextField.text;
        NSString *PFUserUsername = [[PFUser currentUser] username];
        
        PFQuery *query = [PFQuery queryWithClassName:@"_User"];
        [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
            if (error) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                    message:@"Could not find user"
                                                                   delegate:self
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@"OK", nil];
                [alertView show];
                return;
            }else{
                bool foundName;
                foundName = false;
                for (int i = 0; i < PFObjects.count; i++) {
                    NSString *searchedUsername = [PFObjects[i] objectForKey:@"username"];
                    if ([searchedUsername isEqualToString:username] && ![searchedUsername isEqualToString:PFUserUsername]){
                        foundName = true;
                        NSLog(@"\nFOUND USER: %@", username);
                    }
                }
                if (foundName) {
                    NSLog(@"\nADDED USER: %@", username);
                    // Success!
                    NSArray *contacts;
                    if (contactsArray == nil) {//IF IT IS THE FIRST TIME ADDING A CONTACT
                        contacts = [NSArray arrayWithObjects:username, nil];
                    }else{
                        NSMutableArray *temp = [NSMutableArray arrayWithArray:contactsArray];
                        [temp addObject:username];
                        contacts = [NSArray arrayWithArray:temp];
                    }
                    
                    [[PFUser currentUser] setObject:contacts forKey:@"Contacts"];
                    [[PFUser currentUser] saveInBackground];
                }else{
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                        message:@"Could not find user"
                                                                       delegate:self
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil];
                    [alertView show];
                }
            }
            [self loadContacts];
        }];
    }]];
    
    [self presentViewController:enterContactAlert animated:true completion:nil];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"Formal";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell.
    NSString *cellText = [contactsArray objectAtIndex:indexPath.row];
    
    cell.textLabel.text = cellText;
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
