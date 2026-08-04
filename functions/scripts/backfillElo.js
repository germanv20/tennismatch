/**
 * One-off backfill script — seeds eloRating/eloMatchesPlayed for existing
 * users by replaying every completed regular 1v1 match in chronological
 * order (oldest completedAt first), using the exact same Elo formula as
 * functions/index.js's applyEloRatings(). Run this ONCE after deploying
 * Phase 2, so existing testers don't all start flat at 1200 despite
 * already having a match history — someone who's beaten strong opponents
 * repeatedly should show up above 1200 immediately, not after replaying
 * their whole history one live match at a time.
 *
 * This is a plain Node script, NOT a deployed Cloud Function — it isn't
 * exported from index.js and Firebase will never invoke it automatically.
 * `firebase deploy --only functions` ignores anything not exported there.
 *
 * Usage (from the functions/ directory):
 *   1. Download a service account key for the tennismatch-3c79c project:
 *      Firebase Console -> Project settings (gear icon) -> Service
 *      accounts tab -> "Generate new private key". Save the downloaded
 *      file as serviceAccountKey.json directly in this functions/
 *      directory. It's covered by functions/.gitignore — never commit it.
 *   2. npm install (if you haven't already)
 *   3. node scripts/backfillElo.js
 *   4. Delete serviceAccountKey.json once you're done (or keep it if
 *      you'll need it again, but it's a sensitive credential either way).
 *
 * Safe to re-run: every run recomputes eloRating/eloMatchesPlayed from
 * scratch for every user touched by a regular match, rather than adding
 * on top of a previous run's numbers.
 */

const admin = require("firebase-admin");
// eslint-disable-next-line
const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const ELO_STARTING_RATING = 1200;
const ELO_K_FACTOR_PROVISIONAL = 32;
const ELO_K_FACTOR_ESTABLISHED = 16;
const ELO_PROVISIONAL_MATCH_COUNT = 20;

/**
 * Same provisional/established K-factor split as applyEloRatings() in
 * functions/index.js — must stay in sync with that function.
 * @param {number} eloMatchesPlayed
 * @return {number}
 */
function eloKFactor(eloMatchesPlayed) {
  return eloMatchesPlayed < ELO_PROVISIONAL_MATCH_COUNT ?
      ELO_K_FACTOR_PROVISIONAL :
      ELO_K_FACTOR_ESTABLISHED;
}

/**
 * Fetches every completed match, keeps only regular 1v1 matches (skips
 * guest and doubles_guest — same exclusion as the live Cloud Function),
 * and replays them oldest-first to build a final in-memory rating per
 * user, then writes those final numbers to Firestore.
 * @return {Promise<void>}
 */
async function main() {
  console.log("Fetching completed matches...");

  const snapshot = await db.collection("matches")
      .where("status", "==", "completed")
      .orderBy("completedAt", "asc")
      .get();

  const regularMatches = snapshot.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .filter((m) => (m.type || "regular") === "regular")
      .filter((m) =>
        (m.players || []).filter((u) => u && u !== "guest").length === 2);

  console.log(
      `Found ${regularMatches.length} completed regular 1v1 match(es).`,
  );

  // In-memory rating state, keyed by uid — replayed in chronological order.
  const ratings = {}; // uid -> { rating, matchesPlayed }

  /**
   * @param {string} uid
   * @return {{rating: number, matchesPlayed: number}}
   */
  function getState(uid) {
    if (!ratings[uid]) {
      ratings[uid] = {rating: ELO_STARTING_RATING, matchesPlayed: 0};
    }
    return ratings[uid];
  }

  for (const match of regularMatches) {
    const players = match.players.filter((u) => u && u !== "guest");
    const [uidA, uidB] = players;
    const isTie = match.isTie === true;
    const winnerUid = match.winnerUid;

    let scoreA;
    if (isTie) {
      scoreA = 0.5;
    } else if (winnerUid === uidA) {
      scoreA = 1;
    } else if (winnerUid === uidB) {
      scoreA = 0;
    } else {
      console.log(`⚠️ Skipping match ${match.id} — unresolved winner.`);
      continue;
    }
    const scoreB = 1 - scoreA;

    const stateA = getState(uidA);
    const stateB = getState(uidB);

    const expectedA =
        1 / (1 + Math.pow(10, (stateB.rating - stateA.rating) / 400));
    const expectedB = 1 - expectedA;

    const newRatingA = Math.round(
        stateA.rating + eloKFactor(stateA.matchesPlayed) * (scoreA - expectedA),
    );
    const newRatingB = Math.round(
        stateB.rating + eloKFactor(stateB.matchesPlayed) * (scoreB - expectedB),
    );

    stateA.rating = newRatingA;
    stateA.matchesPlayed += 1;
    stateB.rating = newRatingB;
    stateB.matchesPlayed += 1;
  }

  const uids = Object.keys(ratings);
  console.log(`Writing final ratings for ${uids.length} user(s)...`);

  for (const uid of uids) {
    const {rating, matchesPlayed} = ratings[uid];
    await db.collection("users").doc(uid).update({
      eloRating: rating,
      eloMatchesPlayed: matchesPlayed,
    });
    console.log(
        `  ${uid}: eloRating=${rating}, eloMatchesPlayed=${matchesPlayed}`,
    );
  }

  console.log("Done.");
}

main().catch((err) => {
  console.error("Backfill failed:", err);
  process.exit(1);
});
