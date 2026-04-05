import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tennis Match'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'TennisMatch Login'**
  String get loginTitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @userProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User profile not found'**
  String get userProfileNotFound;

  /// No description provided for @signOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmation;

  /// No description provided for @findPlayers.
  ///
  /// In en, this message translates to:
  /// **'Find Players'**
  String get findPlayers;

  /// No description provided for @myMatches.
  ///
  /// In en, this message translates to:
  /// **'My Matches'**
  String get myMatches;

  /// No description provided for @matchHistory.
  ///
  /// In en, this message translates to:
  /// **'Match History'**
  String get matchHistory;

  /// No description provided for @myStats.
  ///
  /// In en, this message translates to:
  /// **'My Stats'**
  String get myStats;

  /// No description provided for @incomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Match Requests'**
  String get incomingRequests;

  /// No description provided for @outgoingRequests.
  ///
  /// In en, this message translates to:
  /// **'Outgoing Requests'**
  String get outgoingRequests;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @selectLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose level'**
  String get selectLevel;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @monFull.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monFull;

  /// No description provided for @tueFull.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tueFull;

  /// No description provided for @wedFull.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wedFull;

  /// No description provided for @thuFull.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thuFull;

  /// No description provided for @friFull.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friFull;

  /// No description provided for @satFull.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get satFull;

  /// No description provided for @sunFull.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunFull;

  /// No description provided for @levelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Begginer'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get levelIntermediate;

  /// No description provided for @levelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get levelAdvanced;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @waitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response'**
  String get waitingForResponse;

  /// No description provided for @requestMatch.
  ///
  /// In en, this message translates to:
  /// **'Request Match'**
  String get requestMatch;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Match request sent 🎾'**
  String get requestSent;

  /// No description provided for @requestAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'Match request already sent'**
  String get requestAlreadySent;

  /// No description provided for @matchRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Match request accepted'**
  String get matchRequestAccepted;

  /// No description provided for @matchRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Match request rejected'**
  String get matchRequestRejected;

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get requestRejected;

  /// No description provided for @matchAccepted.
  ///
  /// In en, this message translates to:
  /// **'Match accepted'**
  String get matchAccepted;

  /// No description provided for @matchCancelled.
  ///
  /// In en, this message translates to:
  /// **'Match cancelled'**
  String get matchCancelled;

  /// No description provided for @availabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Select the days you are available to play'**
  String get availabilityHint;

  /// No description provided for @noIncomingRequests.
  ///
  /// In en, this message translates to:
  /// **'No incoming match requests'**
  String get noIncomingRequests;

  /// No description provided for @noOutgoingRequests.
  ///
  /// In en, this message translates to:
  /// **'No outgoing requests'**
  String get noOutgoingRequests;

  /// No description provided for @noPlayersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No players available'**
  String get noPlayersAvailable;

  /// No description provided for @noMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noMatchesFound;

  /// No description provided for @noActiveMatches.
  ///
  /// In en, this message translates to:
  /// **'No active matches'**
  String get noActiveMatches;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet 👋'**
  String get noMessagesYet;

  /// No description provided for @noMatchHistory.
  ///
  /// In en, this message translates to:
  /// **'No match history yet'**
  String get noMatchHistory;

  /// No description provided for @playerProfile.
  ///
  /// In en, this message translates to:
  /// **'Player Profile'**
  String get playerProfile;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @yourTennisLevel.
  ///
  /// In en, this message translates to:
  /// **'Your tennis level'**
  String get yourTennisLevel;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @noAvailability.
  ///
  /// In en, this message translates to:
  /// **'No availability set'**
  String get noAvailability;

  /// No description provided for @availablePlayers.
  ///
  /// In en, this message translates to:
  /// **'Available Players'**
  String get availablePlayers;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @loginToFindPlayers.
  ///
  /// In en, this message translates to:
  /// **'Please log in to find players'**
  String get loginToFindPlayers;

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load your profile'**
  String get failedToLoadProfile;

  /// No description provided for @failedToLoadPlayers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load players'**
  String get failedToLoadPlayers;

  /// No description provided for @failedToLoadUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user'**
  String get failedToLoadUser;

  /// No description provided for @failedToLoadOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Failed to load outgoing requests'**
  String get failedToLoadOutgoing;

  /// No description provided for @incomingRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match requests you receive will appear here'**
  String get incomingRequestsSubtitle;

  /// No description provided for @outgoingRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests you send will appear here'**
  String get outgoingRequestsSubtitle;

  /// No description provided for @setYourLevel.
  ///
  /// In en, this message translates to:
  /// **'Set your tennis level'**
  String get setYourLevel;

  /// No description provided for @setLevelToFindPlayers.
  ///
  /// In en, this message translates to:
  /// **'Go back and select your level to find players'**
  String get setLevelToFindPlayers;

  /// No description provided for @tryChangingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Try changing your availability or check later'**
  String get tryChangingAvailability;

  /// No description provided for @setAvailabilityToFindPlayers.
  ///
  /// In en, this message translates to:
  /// **'Set availability to find players'**
  String get setAvailabilityToFindPlayers;

  /// No description provided for @playMatchesToSeeHistory.
  ///
  /// In en, this message translates to:
  /// **'Play some matches to see them here 🎾'**
  String get playMatchesToSeeHistory;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @invalidUserData.
  ///
  /// In en, this message translates to:
  /// **'Invalid user data'**
  String get invalidUserData;

  /// No description provided for @availableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableLabel;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @headToHead.
  ///
  /// In en, this message translates to:
  /// **'Head-to-Head'**
  String get headToHead;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorPrefix;

  /// No description provided for @wantsToPlayMatch.
  ///
  /// In en, this message translates to:
  /// **'Wants to play a match'**
  String get wantsToPlayMatch;

  /// No description provided for @unmatchConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unmatch? This will remove the chat.'**
  String get unmatchConfirmation;

  /// No description provided for @unmatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmatch?'**
  String get unmatchTitle;

  /// No description provided for @unmatch.
  ///
  /// In en, this message translates to:
  /// **'Unmatch'**
  String get unmatch;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @myMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'My Matches'**
  String get myMatchesTitle;

  /// No description provided for @failedToLoadMatches.
  ///
  /// In en, this message translates to:
  /// **'Failed to load matches'**
  String get failedToLoadMatches;

  /// No description provided for @refreshOrTryLater.
  ///
  /// In en, this message translates to:
  /// **'Try refreshing or check again later'**
  String get refreshOrTryLater;

  /// No description provided for @startByFindingPlayer.
  ///
  /// In en, this message translates to:
  /// **'Start by finding a player to play with 🎾'**
  String get startByFindingPlayer;

  /// No description provided for @failedToLoadOpponent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load opponent'**
  String get failedToLoadOpponent;

  /// No description provided for @matchActive.
  ///
  /// In en, this message translates to:
  /// **'Match active'**
  String get matchActive;

  /// No description provided for @matchDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get matchDetailsTitle;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @createdAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAtLabel;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open Chat'**
  String get openChat;

  /// No description provided for @addMatchResult.
  ///
  /// In en, this message translates to:
  /// **'Add Match Result'**
  String get addMatchResult;

  /// No description provided for @matchResult.
  ///
  /// In en, this message translates to:
  /// **'Match Result'**
  String get matchResult;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @isTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String isTyping(Object name);

  /// No description provided for @addMatchResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Match Result'**
  String get addMatchResultTitle;

  /// No description provided for @useOfficialScoring.
  ///
  /// In en, this message translates to:
  /// **'Use official tennis scoring'**
  String get useOfficialScoring;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'+ Add Set'**
  String get addSet;

  /// No description provided for @selectMatchDate.
  ///
  /// In en, this message translates to:
  /// **'Select match date'**
  String get selectMatchDate;

  /// No description provided for @matchDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Match Date: {date}'**
  String matchDateLabel(Object date);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationMinutes;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @saveResult.
  ///
  /// In en, this message translates to:
  /// **'Save Result'**
  String get saveResult;

  /// No description provided for @setScoresZeroError.
  ///
  /// In en, this message translates to:
  /// **'Set scores cannot both be zero.'**
  String get setScoresZeroError;

  /// No description provided for @invalidSetScore.
  ///
  /// In en, this message translates to:
  /// **'Invalid tennis set score.'**
  String get invalidSetScore;

  /// No description provided for @addAtLeastOneSet.
  ///
  /// In en, this message translates to:
  /// **'Add at least one set.'**
  String get addAtLeastOneSet;

  /// No description provided for @mustHaveWinner.
  ///
  /// In en, this message translates to:
  /// **'There must be a winner.'**
  String get mustHaveWinner;

  /// No description provided for @enterDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter match duration.'**
  String get enterDuration;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter match location.'**
  String get enterLocation;

  /// No description provided for @selectDateError.
  ///
  /// In en, this message translates to:
  /// **'Select match date.'**
  String get selectDateError;

  /// No description provided for @matchCompleted.
  ///
  /// In en, this message translates to:
  /// **'Match completed 🎾'**
  String get matchCompleted;

  /// No description provided for @playerStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Player Statistics'**
  String get playerStatisticsTitle;

  /// No description provided for @noStatsYet.
  ///
  /// In en, this message translates to:
  /// **'No stats yet'**
  String get noStatsYet;

  /// No description provided for @playFirstMatchStats.
  ///
  /// In en, this message translates to:
  /// **'Play your first match to see your statistics 🎾'**
  String get playFirstMatchStats;

  /// No description provided for @matchesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Matches Played'**
  String get matchesPlayed;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @losses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get losses;

  /// No description provided for @winRate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get winRate;

  /// No description provided for @totalSetsWon.
  ///
  /// In en, this message translates to:
  /// **'Total Sets Won'**
  String get totalSetsWon;

  /// No description provided for @totalSetsLost.
  ///
  /// In en, this message translates to:
  /// **'Total Sets Lost'**
  String get totalSetsLost;

  /// No description provided for @averageMatchDuration.
  ///
  /// In en, this message translates to:
  /// **'Average Match Duration'**
  String get averageMatchDuration;

  /// No description provided for @failedToLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats'**
  String get failedToLoadStats;

  /// No description provided for @failedToOpenFeedbackForm.
  ///
  /// In en, this message translates to:
  /// **'Could not open feedback form'**
  String get failedToOpenFeedbackForm;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String setLabel(Object number);

  /// No description provided for @matchResultSentence.
  ///
  /// In en, this message translates to:
  /// **'{winnerName} defeated {loserName}'**
  String matchResultSentence(Object winnerName, Object loserName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
