#!/bin/bash
echo "🛑 Cloud Functionsを停止します..."
firebase functions:delete fetchBusLocation --force
firebase functions:delete cleanOldLocations --force
firebase functions:delete checkSafeZone --force
firebase functions:delete cleanupSafeZoneEvents --force
firebase functions:delete cleanupOldLocationHistory --force
firebase functions:delete cleanupOldZoneEvents --force
echo "✅ 停止完了！お疲れ様でした！"
