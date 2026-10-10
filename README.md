# SkyDesk ☁️🖥️

سطح مكتب Ubuntu 24.04 كامل يفتح من المتصفح، خفيف ومضبوط ليشتغل حتى على إنترنت ضعيف.

A lightweight Ubuntu 24.04 desktop in your browser, tuned to stay usable on slow connections.

## المميزات
- Ubuntu 24.04 + XFCE خفيف، بدون مؤثرات بصرية (compositing مطفأ، خلفية لون واحد).
- صفحة دخول بثلاثة أوضاع: **نت ضعيف / متوسط / جودة عالية** (ضغط وجودة صورة مضبوطة مسبقاً).
- كلمة سر إلزامية: إذا ما حددت `VNC_PASSWORD` بتتولد وحدة عشوائية وبتنطبع بالـ logs.
- يقرأ المتغير `PORT` تلقائياً، فبيشتغل على أي منصة تنشر من GitHub: Render، Railway، Koyeb، Fly.io، Northflank، Hugging Face Spaces...
- يعمل كمستخدم عادي (UID 1000) مع صلاحية sudo، ودعم الخط العربي.
- صورة جاهزة تُبنى تلقائياً على GitHub Container Registry.

## التشغيل محلياً
```bash
docker compose up -d --build
```
ثم افتح: `http://localhost:6080`

أو بدون compose:
```bash
docker build -t skydesk .
docker run -d -p 6080:6080 -e VNC_PASSWORD=change-me --shm-size=512m skydesk
```

## النشر على سيرفر سحابي
1. اربط هذا المستودع بالمنصة (New → Web Service → من GitHub).
2. اختر **Docker** كطريقة بناء (الـ Dockerfile بالجذر).
3. أضف متغير البيئة `VNC_PASSWORD`.
4. افتح الرابط اللي بتعطيك ياه المنصة.

> ملاحظة: يحتاج 512MB رام على الأقل، و1GB أريح.

## المتغيرات
| المتغير | الافتراضي | الوصف |
|---|---|---|
| `VNC_PASSWORD` | عشوائي | كلمة سر الدخول |
| `PORT` | `6080` | منفذ الويب |
| `RESOLUTION` | `1280x720` | دقة الشاشة (للنت الضعيف جرّب `1024x576`) |
| `DEPTH` | `24` | عمق الألوان (`16` أخف) |
| `TZ` | `UTC` | المنطقة الزمنية |

## نصائح للنت الضعيف
- استخدم "وضع النت الضعيف" بصفحة الدخول.
- خفّف الدقة: `RESOLUTION=1024x576` و`DEPTH=16`.
- اختر سيرفر بمنطقة قريبة منك (مثلاً أوروبا).

## License
MIT
