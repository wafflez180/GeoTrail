//
//  ContactsTableTableViewController.m
//  SnapTrail
//
//  Created by Arthur Araujo on 4/26/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "ContactsTableTableViewController.h"
#import "TabBarController.h"
#import "Contact.h"

@import Firebase;

@interface ContactsTableTableViewController ()

@end

@implementation ContactsTableTableViewController{
    IBOutlet UITableView *tableView;
    NSString *userUID;
    NSMutableArray *contactsArray;
    NSMutableArray *contactIDsArray;
    FIRStorage *firebaseRef;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    TabBarController *tabBarController = (TabBarController *)self.tabBarController;
    userUID = tabBarController.currentUser.uid;
    firebaseRef = tabBarController.firebaseRef;
    contactsArray = [[NSMutableArray alloc] initWithArray:tabBarController.contactsArray];
    contactIDsArray = [[NSMutableArray alloc] initWithArray:tabBarController.contactIDsArray];
    
    //LOAD ALL THE CONTACTS
    [self.tableView reloadData];
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
        // Get a reference to our users
        FIRDatabaseReference *usersRef = [[FIRDatabase database] referenceWithPath:[firebaseRef.reference.fullPath stringByAppendingString:@"users"]];
//        Firebase* tempRef1 = [firebaseRef childByAppendingPath:@"users"];
        
        // Attach a block to read the data at our users reference
        [usersRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
            //GET ALL THE USERS AND THEN QUERY FROM THERE
//            Firebase* tempRef2 = [firebaseRef childByAppendingPath:[NSString stringWithFormat:@"users/%@", snapshot.key]];
            FIRDatabaseReference *userRef = [[FIRDatabase database] referenceWithPath:[firebaseRef.reference.fullPath stringByAppendingString:[NSString stringWithFormat:@"users/%@", snapshot.key]]];

            [userRef queryEqualToValue:username childKey:@"displayName"];
            // Attach a block to read the data at our users reference
            [userRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
                NSLog(@"\nADDED USER: %@", snapshot.value[@"displayName"]);
                // Success!
                //GO TO THE USER AND UPDATE THEIR CONTACTS
                [contactIDsArray addObject:snapshot.key];
                NSDictionary *contacts = @{
                                           @"contacts": [NSArray arrayWithArray:contactIDsArray],
                                           };
                //Send update to firebase
                [userRef updateChildValues: contacts];
                //Reload table
                [self.tableView reloadData];
            } withCancelBlock:^(NSError *error) {
                //ERROR
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                    message:@"Could not find user"
                                                                   delegate:self
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@"OK", nil];
                [alertView show];
                NSLog(@"%@", error.description);
                NSLog(@"%@", error.description);
            }];
        } withCancelBlock:^(NSError *error) {
            
        }];
    }]];
    
    [self presentViewController:enterContactAlert animated:true completion:nil];
}

-(void)loadContactListData{
    contactsArray = [[NSMutableArray alloc] init];
    //Go through each contact and get their data
    for(int i = 0; i < contactIDsArray.count; i++){
        // Attach a block to read the data at our users
        
        //Get the contact that matches with the contactID
//        Firebase *ref = [[Firebase alloc] initWithUrl:[NSString stringWithFormat:@"https://incandescent-inferno-4410.firebaseio.com/users/%@",contactIDsArray[i]]];
        FIRDatabaseReference *userContactRef = [[FIRDatabase database] referenceWithPath:[firebaseRef.reference.fullPath stringByAppendingString:[NSString stringWithFormat:@"users/%@", contactIDsArray[i]]]];

        [userContactRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
            //TO DO: ADD EVERY VALUE OF CONTACT
            Contact *currentContact = [[Contact alloc] initWithName:snapshot.value[@"displayName"] uid:snapshot.key  unlockedHexsLatitude:[snapshot.value[@"unlockedHexsLatitude"] doubleValue]unlockedHexsLongitude: [snapshot.value[@"unlockedHexsLongitude"] doubleValue]];
            [contactsArray addObject:currentContact];
            //After the last contact is loaded, load their data onto the map
            if (i == (int)contactsArray.count) {
                TabBarController *tabBarController = (TabBarController *)self.tabBarController;
                tabBarController.contactsArray = contactsArray;
                [self.tableView reloadData];
            }
        } withCancelBlock:^(NSError *error) {
            NSLog(@"%@", error.description);
        }];
    }
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
    Contact *currentContact = (Contact *)[contactsArray objectAtIndex:indexPath.row];
    NSString *cellText = currentContact.userName;
    
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
