//
//  T3ViewController.m
//  TicTacToe
//
//  Created by Ethan Jud on 1/30/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "T3ViewController.h"
#import "T3Game.h"
#import "T3ComputerPlayer.h"

static void* kObservationContext = &kObservationContext;

static NSUInteger kRowCount = 3;
static NSUInteger kColCount = 3;

@interface T3ViewController () <UIAlertViewDelegate>

@property (retain, nonatomic) IBOutlet UIView *gameBoardView;

// The index of a button in this array should be the same as its tag,
// which should be equal to its row * kColCount + col
@property (strong, nonatomic) NSArray *gameBoardButtons;

@property (strong, nonatomic) T3Game *game;
@property (strong, nonatomic) T3ComputerPlayer *computerPlayer;

@end

@implementation T3ViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize the game and computer player.
    _game = [[T3Game alloc] init];
    _computerPlayer = [[T3ComputerPlayer alloc] init];
    
    // Start observations
    [self.game addObserver:self
                forKeyPath:@"currentPlayer"
                   options:0
                   context:kObservationContext];
    
    [self.game addObserver:self
                forKeyPath:@"isGameOver"
                   options:0
                   context:kObservationContext];
    
    // Initialize the game board buttons.
    // These buttons are "custom" and they have no border.
    // They act as hot spots overlayed on top of the game
    //  board image for taking turns.
    // They also display the current player at the square
    //  as @"X" or @"O", if applicable.
    NSMutableArray *boardButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < kRowCount * kColCount; ++i) {
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:48.0];
        
        // The button's tag is equal to row * 3 + col.
        // We'll use this to position it and to recognize
        //  the user tapping on it.
        button.tag = i;
        
        [button addTarget:self
                   action:@selector(boardButtonTapped:)
         forControlEvents:UIControlEventTouchUpInside];
        
        [boardButtons addObject:button];
        
        [self.gameBoardView addSubview:button];
    }
    
    self.gameBoardButtons = boardButtons;
    
    // Start the first game.
    [self startHumanComputerGameWithComputerAsPlayer:T3PlayerO];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    // Position the buttons in the view.
    CGFloat buttonWidth = self.gameBoardView.bounds.size.width / kColCount;
    CGFloat buttonHeight = self.gameBoardView.bounds.size.height / kRowCount;
    
    for (UIButton *button in self.gameBoardButtons) {
        // Extract the row and column from the button tag.
        // This determines its location.
        NSUInteger row = button.tag / kColCount;
        NSUInteger col = button.tag % kColCount;
        
        button.frame = CGRectMake(col * buttonWidth,
                                  row * buttonHeight,
                                  buttonWidth,
                                  buttonHeight);
        [button.titleLabel sizeToFit];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [self.game removeObserver:self forKeyPath:@"currentPlayer"];
    [self.game removeObserver:self forKeyPath:@"isGameOver"];
    
    [_gameBoardView release];
    [_gameBoardButtons release];
    
    [_computerPlayer release];
    [_game release];
    
    [super dealloc];
}

#pragma mark - Game UI

// Refreshes the entire board UI, one square at a time.
- (void)refreshBoard
{
    for (NSUInteger row = 0; row < kRowCount; ++row) {
        for (NSUInteger col = 0; col < kColCount; ++col) {
            [self refreshSquareAtRow:row col:col];
        }
    }
}

// Refreshes a square's display at the specified row and column.
- (void)refreshSquareAtRow:(NSUInteger)row col:(NSUInteger)col
{
    NSUInteger index = row * kColCount + col;
    UIButton *button = [self.gameBoardButtons objectAtIndex:index];
    
    // Update the title label
    NSString *title = ^NSString *() {
        switch ([self.game playerOccupyingRow:row col:col]) {
            case T3PlayerNone:
                return @"";
            case T3PlayerX:
                return @"X";
            case T3PlayerO:
                return @"O";
        }
    }();
    [button setTitle:title forState:UIControlStateNormal];
}

// Called when a button on the board is tapped.
- (void)boardButtonTapped:(id)sender
{
    if (![sender isKindOfClass:[UIButton class]]) {
        NSAssert(0, @"Unexpected sender");
        return;
    }
    
    if (self.game.currentPlayer == self.computerPlayer.player) {
        // It's the computer's turn. Do nothing.
        return;
    }
    
    UIButton *button = sender;
    NSUInteger row = button.tag / kColCount;
    NSUInteger col = button.tag % kColCount;
    
    if ([self.game playerOccupyingRow:row col:col]) {
        // Don't try to play the square if it's already occupied.
        return;
    }
    
    [self.game playSquareOnRow:row col:col];
}

// Starts a human vs. human game.
- (void)startHumanHumanGame
{
    [self.computerPlayer stopPlaying];
    [self.game resetGame];
}

// Starts a human vs. computer game
- (void)startHumanComputerGameWithComputerAsPlayer:(T3Player)computerPlayer;
{
    [self.computerPlayer stopPlaying];
    [self.game resetGame];
    [self.computerPlayer startPlayingGame:self.game asPlayer:computerPlayer];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != kObservationContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if (object != self.game) {
        return;
    }
    
    if ([keyPath isEqualToString:@"currentPlayer"]) {
        // If the current player changes, we know that a
        //  move was played and the board needs to be updated.
        [self refreshBoard];
    }
    else if ([keyPath isEqualToString:@"isGameOver"]) {
        if (!self.game.isGameOver) {
            return;
        }
        
        NSString *title = NSLocalizedString(@"Game Over", nil);
        NSString *message = ^NSString *() {
            switch (self.game.winner) {
                case T3PlayerNone:
                    return NSLocalizedString(@"The game ended in a draw", nil);
                case T3PlayerX:
                    return NSLocalizedString(@"Player X is the winner!", nil);
                case T3PlayerO:
                    return NSLocalizedString(@"Player O is the winner!", nil);
            }
        }();
        
        NSString *newGameXTitle = NSLocalizedString(@"New Game as X", nil);
        NSString *newGameOTitle = NSLocalizedString(@"New Game as O", nil);
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:newGameXTitle, newGameOTitle, nil];
        [alertView show];
    }
}

#pragma mark - New Game UI

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // The only way this can be called is if the user tapped the "New Game" button in an alert view.
    [self.game resetGame];
    
    T3Player computerPlayer = (buttonIndex == 0) ? T3PlayerO : T3PlayerX;
    [self startHumanComputerGameWithComputerAsPlayer:computerPlayer];
}

@end
