# Deploy guide (Render + PlanetScale + Cloudinary)

## 1) PlanetScale (MySQL)
1. Create DB on PlanetScale.
2. Create a password (branch credentials).
3. Copy connection string and use it in `DATABASE_URL` on Render.

Example format:
`mysql://USER:PASSWORD@HOST/medical_suivi?ssl={"rejectUnauthorized":true}`

If PlanetScale gives host/user/pass separately, you can also use:
- `DB_HOST`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME=medical_suivi`
- `DB_SSL=true`

## 2) Cloudinary (files)
1. Create Cloudinary account.
2. Get:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
3. Optional: `CLOUDINARY_FOLDER=medical-suivi`

## 3) Render (backend)
1. Render dashboard → New + → Web Service.
2. Connect GitHub repo: `zedmort/medical-suivi`.
3. Root directory: `backend`.
4. Build command: `npm install`
5. Start command: `npm start`
6. Add env vars:
- `NODE_ENV=production`
- `JWT_SECRET=<long-random-secret>`
- `JWT_EXPIRES_IN=24h`
- `DB_SSL=true`
- `DATABASE_URL=<PlanetScale connection string>`
- `CLOUDINARY_CLOUD_NAME=...`
- `CLOUDINARY_API_KEY=...`
- `CLOUDINARY_API_SECRET=...`
- `CLOUDINARY_FOLDER=medical-suivi`

Health check path: `/`

## 4) Database schema
After first deploy:
- Render Shell (or local with same env) run:
`npm run migrate`

## 5) Test API
- `https://<your-render-service>.onrender.com/`
should return:
`{"message":"Medical API is running."}`

## 6) Mobile app
Run Flutter with hosted API:
`flutter run --dart-define=API_BASE_URL=https://<your-render-service>.onrender.com/api`

## Notes
- Render free web services can sleep when inactive.
- Cloudinary removes dependency on local disk for uploads.
- This backend keeps local upload fallback for local dev if Cloudinary env vars are absent.
