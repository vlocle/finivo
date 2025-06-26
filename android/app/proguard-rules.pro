# Quy tắc cho Google Play Billing Library
-keep class com.android.billingclient.api.** { *; }

# Quy tắc cho RevenueCat SDK (Flutter)
# Giữ lại tất cả các class và interface cần thiết cho SDK chính và phần hybrid.
-dontwarn com.revenuecat.purchases.**
-keep class com.revenuecat.purchases.** { *; }
-keep interface com.revenuecat.purchases.** { *; }
-keep class com.revenuecat.purchases.hybridcommon.** { *; }
-keep interface com.revenuecat.purchases.hybridcommon.** { *; }

# Quy tắc bổ sung cho Paywalls (purchases_ui_flutter)
-keep class com.revenuecat.purchases.ui.revenuecatui.** { *; }
-keep interface com.revenuecat.purchases.ui.revenuecatui.** { *; }