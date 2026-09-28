# NovaCoin economy

NovaCoin (NVC) is SocialNova's own virtual currency.

## Flow

1. User buys a consumable NovaCoin package through the mobile store.
2. The app receives the store purchase event.
3. The app creates/updates a server-side purchase order.
4. Production server verification must validate the store receipt/token before crediting coins.
5. Coins live in the user's `Wallet.coinBalance`.
6. Sending a gift atomically subtracts coins from the sender.
7. The recipient receives a configurable share (default 70%) in `withdrawableCoins`.
8. A withdrawal request reserves the withdrawable coins and enters `PENDING`.
9. Admin marks the request `PAID` or `REJECTED`; rejected requests refund the reserved coins.

## Default gifts

| Gift | Price |
|---|---:|
| 🌹 وردة | 10 NVC |
| ❤️ قلب | 25 NVC |
| ⭐ نجمة | 100 NVC |
| 👑 تاج | 500 NVC |
| 🚀 صاروخ | 1,000 NVC |
| 🌌 مجرة | 5,000 NVC |

## Contexts

Gifts can be sent in:

- `LIVE`
- `POST`
- `REEL`
- `COMMENT`

The transaction stores the context and context ID for audit/history.

## Withdrawal

- Default minimum: 1,000 withdrawable NVC.
- Default withdrawal fee: 10% of requested NVC.
- Default conversion: 100 withdrawable NVC = $1.00 before the withdrawal fee.
- Cash-out is restricted to accounts that have a verified birth date and are 18+.
- A real payout provider/bank/PayPal integration still has to be connected to the admin `PAID` step.

## Production purchase verification

Do not set `IAP_VERIFICATION_MODE=DEMO` in production. The current code deliberately refuses to credit coins from an unverified client claim. Connect Google Play/App Store server-side verification, then credit the order only after the store confirms the transaction.

## Database

Run `npx prisma db push` after deploying the schema. The server automatically creates/updates the default gift catalog on startup.
