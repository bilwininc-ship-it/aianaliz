/**
 * Firebase Cloud Functions - AI Spor Pro
 * Google Play IAP Verification + Match Pool Updates
 * Updated to Firebase Functions v2 API
 */

const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {logger} = require("firebase-functions/logger");
const admin = require("firebase-admin");
const https = require("https");
const {google} = require("googleapis");

// Set global options for all functions
setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
});

// Firebase Admin initialize
admin.initializeApp();

// Environment variables for local testing
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

// ============================================
// 🔒 GOOGLE PLAY IAP VERIFICATION
// ============================================

/**
 * 🔥 CALLABLE: Verify Google Play purchase and add credits
 */
exports.verifyPurchaseAndAddCredits = onCall(
    {
      enforceAppCheck: false,
      timeoutSeconds: 60,
      memory: "256MiB",
      secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"],
    },
    async (request) => {
      // 1. ⭐ FIX: Enhanced authentication check with better logging
      logger.info("🔍 Function çağrıldı:", {
        hasAuth: !!request.auth,
        userId: request.auth?.uid || "NONE",
      });

      if (!request.auth) {
        logger.error("❌ Auth context yok:", {
          hasAuth: !!request.auth,
        });

        throw new HttpsError(
            "unauthenticated",
            "Kullanıcı girişi doğrulanamadı. Lütfen tekrar giriş yapın.",
        );
      }

      const userId = request.auth.uid;
      const {purchaseToken, productId, platform} = request.data;

      logger.info("🔍 Satın alma talebi:", {
        userId: userId,
        productId: productId,
        platform: platform || "android",
        hasToken: !!purchaseToken,
        tokenLength: purchaseToken ? purchaseToken.length : 0,
      });

      // 2. Validate parameters
      if (!purchaseToken || !productId) {
        throw new HttpsError(
            "invalid-argument",
            "purchaseToken ve productId gerekli",
        );
      }

      try {
        // 3. Verify Google Play purchase
        logger.info(`🔍 Satın alma doğrulanıyor: ${userId} - ${productId}`);

        const isValid = await verifyGooglePlayPurchase(
            purchaseToken,
            productId,
        );

        if (!isValid) {
          await logSuspiciousActivity(userId, "invalid_purchase", {
            productId,
            purchaseToken: purchaseToken.substring(0, 20),
          });

          throw new HttpsError(
              "invalid-argument",
              "Satın alma doğrulanamadı",
          );
        }

        // 4. Check for duplicate purchases
        const isDuplicate = await checkDuplicatePurchase(
            userId,
            purchaseToken,
        );

        if (isDuplicate) {
          logger.warn(`⚠️ Duplicate satın alma: ${userId}`);
          throw new HttpsError(
              "already-exists",
              "Bu satın alma daha önce kullanılmış",
          );
        }

        // 5. Get credit amount from product ID
        const creditAmount = getCreditAmountFromProduct(productId);

        if (creditAmount === 0) {
          throw new HttpsError(
              "invalid-argument",
              "Geçersiz ürün ID",
          );
        }

        // 6. Add credits to Firebase (SERVER ONLY)
        const db = admin.database();
        const userRef = db.ref(`users/${userId}`);
        const snapshot = await userRef.get();

        if (!snapshot.exists()) {
          throw new HttpsError(
              "not-found",
              "Kullanıcı bulunamadı",
          );
        }

        const userData = snapshot.val();
        const currentCredits = userData.credits || 0;
        const newCredits = currentCredits + creditAmount;

        // Update credits
        await userRef.update({
          credits: newCredits,
        });

        // 7. Create transaction record
        const transactionRef = db.ref("credit_transactions").push();
        await transactionRef.set({
          userId: userId,
          type: "purchase",
          amount: creditAmount,
          balanceAfter: newCredits,
          createdAt: admin.database.ServerValue.TIMESTAMP,
          description: `Kredi satın alma - ${productId}`,
          productId: productId,
          purchaseId: purchaseToken.substring(0, 50),
          verified: true,
        });

        // 8. Log purchase
        const purchaseLogRef = db.ref("purchase_logs").push();
        await purchaseLogRef.set({
          userId: userId,
          productId: productId,
          purchaseToken: purchaseToken.substring(0, 50),
          creditAmount: creditAmount,
          createdAt: admin.database.ServerValue.TIMESTAMP,
          verified: true,
          platform: platform || "google_play",
        });

        logger.info(
            `✅ Kredi eklendi: ${userId} - ${creditAmount} kredi`,
        );

        return {
          success: true,
          creditsAdded: creditAmount,
          newBalance: newCredits,
          message: `${creditAmount} kredi hesabınıza eklendi`,
        };
      } catch (error) {
        logger.error("❌ Kredi ekleme hatası:", error);

        await logSuspiciousActivity(userId, "purchase_error", {
          productId,
          error: error.message,
        });

        // Re-throw HttpsError as-is
        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            `Satın alma işlemi başarısız: ${error.message}`,
        );
      }
    },
);

/**
 * 🔥 CALLABLE: Verify Google Play purchase and set premium
 */
exports.verifyPurchaseAndSetPremium = onCall(
    {
      enforceAppCheck: false,
      timeoutSeconds: 60,
      memory: "256MiB",
      secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"],
    },
    async (request) => {
      // 1. ⭐ FIX: Enhanced authentication check with better logging
      logger.info("🔍 Premium function çağrıldı:", {
        hasAuth: !!request.auth,
        userId: request.auth?.uid || "NONE",
      });

      if (!request.auth) {
        logger.error("❌ Auth context yok:", {
          hasAuth: !!request.auth,
        });

        throw new HttpsError(
            "unauthenticated",
            "Kullanıcı girişi doğrulanamadı. Lütfen tekrar giriş yapın.",
        );
      }

      const userId = request.auth.uid;
      const {purchaseToken, productId, platform} = request.data;

      logger.info("🔍 Premium satın alma talebi:", {
        userId: userId,
        productId: productId,
        platform: platform || "android",
        hasToken: !!purchaseToken,
      });

      // 2. Validate parameters
      if (!purchaseToken || !productId) {
        throw new HttpsError(
            "invalid-argument",
            "purchaseToken ve productId gerekli",
        );
      }

      try {
        logger.info(
            `🔍 Premium satın alma doğrulanıyor: ${userId} - ${productId}`,
        );

        // 3. Verify subscription
        const isValid = await verifyGooglePlaySubscription(
            purchaseToken,
            productId,
        );

        if (!isValid) {
          await logSuspiciousActivity(
              userId,
              "invalid_premium_purchase",
              {
                productId,
                purchaseToken: purchaseToken.substring(0, 20),
              },
          );

          throw new HttpsError(
              "invalid-argument",
              "Satın alma doğrulanamadı",
          );
        }

        // 4. Check for duplicates
        const isDuplicate = await checkDuplicatePurchase(
            userId,
            purchaseToken,
        );

        if (isDuplicate) {
          throw new HttpsError(
              "already-exists",
              "Bu satın alma daha önce kullanılmış",
          );
        }

        // 5. Get premium duration
        const premiumDays = getPremiumDaysFromProduct(productId);

        if (premiumDays === 0) {
          throw new HttpsError(
              "invalid-argument",
              "Geçersiz premium ürün ID",
          );
        }

        // 6. Set premium (SERVER ONLY)
        const db = admin.database();
        const userRef = db.ref(`users/${userId}`);
        const snapshot = await userRef.get();

        if (!snapshot.exists()) {
          throw new HttpsError(
              "not-found",
              "Kullanıcı bulunamadı",
          );
        }

        const expiresAt = Date.now() + (premiumDays * 24 * 60 * 60 * 1000);

        await userRef.update({
          isPremium: true,
          premiumExpiresAt: expiresAt,
        });

        // 7. Create transaction record
        const transactionRef = db.ref("credit_transactions").push();
        await transactionRef.set({
          userId: userId,
          type: "premium",
          amount: 0,
          balanceAfter: 0,
          createdAt: admin.database.ServerValue.TIMESTAMP,
          description: `Premium abonelik - ${premiumDays} gün`,
          productId: productId,
          purchaseId: purchaseToken.substring(0, 50),
          verified: true,
        });

        // 8. Log purchase
        const purchaseLogRef = db.ref("purchase_logs").push();
        await purchaseLogRef.set({
          userId: userId,
          productId: productId,
          purchaseToken: purchaseToken.substring(0, 50),
          premiumDays: premiumDays,
          createdAt: admin.database.ServerValue.TIMESTAMP,
          verified: true,
          platform: platform || "google_play",
        });

        logger.info(
            `✅ Premium eklendi: ${userId} - ${premiumDays} gün`,
        );

        return {
          success: true,
          premiumDays: premiumDays,
          expiresAt: expiresAt,
          message: `${premiumDays} günlük premium üyelik aktif edildi`,
        };
      } catch (error) {
        logger.error("❌ Premium ekleme hatası:", error);

        await logSuspiciousActivity(userId, "premium_purchase_error", {
          productId,
          error: error.message,
        });

        // Re-throw HttpsError as-is
        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            `Premium aktivasyon başarısız: ${error.message}`,
        );
      }
    },
);

// ============================================
// 🛠️ HELPER FUNCTIONS
// ============================================

/**
 * Verify Google Play in-app purchase (one-time products)
 * @param {string} purchaseToken - Purchase token
 * @param {string} productId - Product ID
 * @return {Promise<boolean>} Verification result
 */
async function verifyGooglePlayPurchase(purchaseToken, productId) {
  try {
    const auth = await getGoogleAuth();
    const androidpublisher = google.androidpublisher({
      version: "v3",
      auth: auth,
    });

    const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME ||
      "com.aisporanaliz.app";

    logger.info(
        `📱 Verifying purchase for package: ${packageName}`,
    );

    const response = await androidpublisher.purchases.products.get({
      packageName: packageName,
      productId: productId,
      token: purchaseToken,
    });

    // purchaseState: 0 = purchased, 1 = canceled
    const isValid = response.data.purchaseState === 0;

    logger.info(
        `🔍 Purchase verification result: ${isValid}`,
        {purchaseState: response.data.purchaseState},
    );

    return isValid;
  } catch (error) {
    logger.error(
        "❌ Google Play verification error:",
        error.message,
    );
    return false;
  }
}

/**
 * Verify Google Play subscription
 * @param {string} purchaseToken - Purchase token
 * @param {string} subscriptionId - Subscription ID
 * @return {Promise<boolean>} Verification result
 */
async function verifyGooglePlaySubscription(purchaseToken, subscriptionId) {
  try {
    const auth = await getGoogleAuth();
    const androidpublisher = google.androidpublisher({
      version: "v3",
      auth: auth,
    });

    const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME ||
      "com.aisporanaliz.app";

    const response = await androidpublisher.purchases.subscriptions.get({
      packageName: packageName,
      subscriptionId: subscriptionId,
      token: purchaseToken,
    });

    // paymentState: 0 = pending, 1 = received
    const isValid = response.data.paymentState === 1;

    logger.info(
        `🔍 Subscription verification result: ${isValid}`,
        {paymentState: response.data.paymentState},
    );

    return isValid;
  } catch (error) {
    logger.error(
        "❌ Subscription verification error:",
        error.message,
    );
    return false;
  }
}

/**
 * Get Google Auth client
 * @return {Promise<Object>} Auth client
 */
async function getGoogleAuth() {
  const serviceAccountKey = process.env.GOOGLE_SERVICE_ACCOUNT_KEY;

  if (serviceAccountKey) {
    try {
      // Parse JSON from Firebase secret
      const credentials = JSON.parse(serviceAccountKey);
      logger.info("✅ Service account credentials loaded from secret");

      const auth = new google.auth.GoogleAuth({
        credentials: credentials,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
      });
      return auth.getClient();
    } catch (error) {
      logger.error("❌ Failed to parse service account key:", error.message);
      throw new Error("Invalid service account credentials");
    }
  } else {
    // Fallback: Try default credentials
    logger.warn("⚠️ No service account key found, using default credentials");
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    return auth.getClient();
  }
}

/**
 * Check for duplicate purchases
 * @param {string} userId - User ID
 * @param {string} purchaseToken - Purchase token
 * @return {Promise<boolean>} True if duplicate
 */
async function checkDuplicatePurchase(userId, purchaseToken) {
  const db = admin.database();
  const tokenPrefix = purchaseToken.substring(0, 50);

  const query = db.ref("purchase_logs")
      .orderByChild("purchaseToken")
      .equalTo(tokenPrefix)
      .limitToFirst(1);

  const snapshot = await query.get();
  return snapshot.exists();
}

/**
 * Log suspicious activity
 * @param {string} userId - User ID
 * @param {string} activityType - Activity type
 * @param {Object} details - Details
 * @return {Promise<void>} Promise
 */
async function logSuspiciousActivity(userId, activityType, details) {
  const db = admin.database();
  const logRef = db.ref("suspicious_activity").push();

  await logRef.set({
    userId: userId,
    activityType: activityType,
    details: details,
    createdAt: admin.database.ServerValue.TIMESTAMP,
    ipAddress: null,
  });

  logger.warn(
      `⚠️ Şüpheli aktivite: ${userId} - ${activityType}`,
      details,
  );
}

/**
 * Get credit amount from product ID
 * @param {string} productId - Product ID
 * @return {number} Credit amount
 */
function getCreditAmountFromProduct(productId) {
  const creditMap = {
    "credits_5": 5,
    "credits_10": 10,
    "credits_25": 25,
    "credits_50": 50,
  };

  return creditMap[productId] || 0;
}

/**
 * Get premium days from product ID
 * @param {string} productId - Product ID
 * @return {number} Days
 */
function getPremiumDaysFromProduct(productId) {
  const premiumMap = {
    "premium_monthly": 30,
    "premium_3months": 90,
    "premium_yearly": 365,
  };

  return premiumMap[productId] || 0;
}

// ============================================
// ⚽ MATCH POOL UPDATES
// ============================================

/**
 * 🔥 HTTP FUNCTION: Manual Match Pool update
 */
exports.updateMatchPoolManual = onRequest(async (req, res) => {
  logger.info("🔥 Manuel Match Pool Update çağrıldı");

  try {
    const result = await updateMatchPoolLogic();
    res.status(200).json({
      success: true,
      message: "Match Pool güncellendi",
      ...result,
    });
  } catch (error) {
    logger.error(
        "❌ Match Pool güncelleme hatası:",
        error,
    );
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Match Pool update logic - ALL MATCHES
 * @return {Promise<Object>} Update result
 */
async function updateMatchPoolLogic() {
  const db = admin.database();

  // Get API key from Remote Config
  const configSnapshot = await db.ref("remoteConfig/API_FOOTBALL_KEY").get();
  const apiKey = configSnapshot.val();

  if (!apiKey) {
    throw new Error("API_FOOTBALL_KEY bulunamadı");
  }

  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);

  let totalMatches = 0;
  const uniqueLeagues = new Set();

  // Fetch today's matches
  logger.info("🔥 Bugün oynanan tüm maçlar çekiliyor...");
  const todayMatches = await fetchAllFixturesForDate(
      apiKey,
      formatDate(now),
  );

  if (todayMatches.length > 0) {
    for (const match of todayMatches) {
      const date = match.date;
      const fixtureId = match.fixtureId.toString();
      await db.ref(`matchPool/${date}/${fixtureId}`).set(match);
      uniqueLeagues.add(match.leagueId);
    }
    totalMatches += todayMatches.length;
    logger.info(`✅ Bugün: ${todayMatches.length} maç eklendi`);
  }

  // Rate limit protection
  await sleep(500);

  // Fetch tomorrow's matches
  logger.info("🔥 Yarın oynanan tüm maçlar çekiliyor...");
  const tomorrowMatches = await fetchAllFixturesForDate(
      apiKey,
      formatDate(tomorrow),
  );

  if (tomorrowMatches.length > 0) {
    for (const match of tomorrowMatches) {
      const date = match.date;
      const fixtureId = match.fixtureId.toString();
      await db.ref(`matchPool/${date}/${fixtureId}`).set(match);
      uniqueLeagues.add(match.leagueId);
    }
    totalMatches += tomorrowMatches.length;
    logger.info(`✅ Yarın: ${tomorrowMatches.length} maç eklendi`);
  }

  // Update metadata
  const nextUpdate = now.getTime() + (6 * 60 * 60 * 1000);
  await db.ref("poolMetadata").update({
    lastUpdate: admin.database.ServerValue.TIMESTAMP,
    totalMatches: totalMatches,
    leagues: Array.from(uniqueLeagues),
    leagueCount: uniqueLeagues.size,
    nextUpdate: nextUpdate,
  });

  // Clean old matches
  await cleanOldMatches(db);

  logger.info(
      `🎉 Toplam ${totalMatches} maç güncellendi ` +
      `(${uniqueLeagues.size} farklı lig)`,
  );

  return {
    totalMatches,
    leagues: uniqueLeagues.size,
    timestamp: now.toISOString(),
  };
}

/**
 * Fetch all fixtures for a specific date
 * @param {string} apiKey - API key
 * @param {string} date - Date (YYYY-MM-DD)
 * @return {Promise<Array>} Matches array
 */
async function fetchAllFixturesForDate(apiKey, date) {
  const url = `https://v3.football.api-sports.io/fixtures?date=${date}`;

  try {
    logger.info(`📡 API Request: /fixtures?date=${date}`);

    const data = await makeHttpsRequest(url, apiKey);
    const fixtures = data.response || [];

    logger.info(
        `📊 API Response: ${fixtures.length} maç bulundu`,
    );

    const matches = [];

    for (const fixture of fixtures) {
      const match = {
        fixtureId: fixture.fixture.id,
        homeTeam: cleanTeamName(fixture.teams.home.name),
        awayTeam: cleanTeamName(fixture.teams.away.name),
        homeTeamId: fixture.teams.home.id,
        awayTeamId: fixture.teams.away.id,
        league: fixture.league.name,
        leagueId: fixture.league.id,
        date: fixture.fixture.date.split("T")[0],
        time: fixture.fixture.date.split("T")[1].substring(0, 5),
        timestamp: new Date(fixture.fixture.date).getTime(),
        status: fixture.fixture.status.short,
        homeStats: null,
        awayStats: null,
        h2h: [],
        lastUpdated: Date.now(),
      };

      matches.push(match);
    }

    return matches;
  } catch (error) {
    logger.error(
        `❌ Tarih ${date} çekme hatası:`,
        error.message,
    );
    return [];
  }
}

/**
 * Make HTTPS request
 * @param {string} url - Request URL
 * @param {string} apiKey - API key
 * @return {Promise<Object>} API response
 */
function makeHttpsRequest(url, apiKey) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        "x-apisports-key": apiKey,
      },
    };

    https.get(url, options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error("JSON parse error"));
        }
      });
    }).on("error", (error) => {
      reject(error);
    });
  });
}

/**
 * Clean old matches
 * @param {Object} db - Firebase database reference
 * @return {Promise<void>} Cleanup result
 */
async function cleanOldMatches(db) {
  const cutoffTime = Date.now() - (3 * 60 * 60 * 1000);

  const snapshot = await db.ref("matchPool").get();

  if (snapshot.exists()) {
    let deletedCount = 0;
    const updates = {};

    snapshot.forEach((dateSnapshot) => {
      const date = dateSnapshot.key;

      dateSnapshot.forEach((matchSnapshot) => {
        const matchData = matchSnapshot.val();

        if (matchData.timestamp < cutoffTime) {
          updates[`matchPool/${date}/${matchSnapshot.key}`] = null;
          deletedCount++;
        }
      });
    });

    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
      logger.info(`🗑️ ${deletedCount} eski maç temizlendi`);
    }
  }
}

// Helper functions
/**
 * Format date to YYYY-MM-DD
 * @param {Date} date - Date object
 * @return {string} Formatted date
 */
function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Clean Turkish characters from team name
 * @param {string} name - Team name
 * @return {string} Cleaned name
 */
function cleanTeamName(name) {
  const map = {
    "ç": "c", "Ç": "C", "ğ": "g", "Ğ": "G",
    "ı": "i", "İ": "I", "ö": "o", "Ö": "O",
    "ş": "s", "Ş": "S", "ü": "u", "Ü": "U",
  };

  let clean = name;
  Object.keys(map).forEach((turkish) => {
    clean = clean.replace(new RegExp(turkish, "g"), map[turkish]);
  });

  return clean.trim();
}

/**
 * Sleep helper function
 * @param {number} ms - Milliseconds
 * @return {Promise<void>} Sleep promise
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

