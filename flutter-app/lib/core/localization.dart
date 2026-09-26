import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  AppLocale._();
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  static const supported = <Locale>[
    Locale('ar'), Locale('fr'), Locale('en'), Locale('es'), Locale('tr'), Locale('de'), Locale('ru'),
  ];

  static const names = <String, String>{
    'ar': 'العربية', 'fr': 'Français', 'en': 'English', 'es': 'Español',
    'tr': 'Türkçe', 'de': 'Deutsch', 'ru': 'Русский',
  };

  static const flags = <String, String>{
    'ar': '🇩🇿', 'fr': '🇫🇷', 'en': '🇬🇧', 'es': '🇪🇸', 'tr': '🇹🇷', 'de': '🇩🇪', 'ru': '🇷🇺',
  };

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('app_language') ?? 'ar';
    final valid = supported.any((l) => l.languageCode == code) ? code : 'ar';
    locale.value = Locale(valid);
  }

  static Future<void> set(String code) async {
    if (!supported.any((l) => l.languageCode == code)) return;
    locale.value = Locale(code);
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', code);
  }

  static bool get isRtl => locale.value.languageCode == 'ar';
}

class L10n {
  static String language(String code) => AppLocale.names[code] ?? code;
  static String flag(String code) => AppLocale.flags[code] ?? '🌐';

  static String text(String key, String code) {
    const m = <String, Map<String, String>>{
      'settings': {'ar':'الإعدادات','fr':'Paramètres','en':'Settings','es':'Ajustes','tr':'Ayarlar','de':'Einstellungen','ru':'Настройки'},
      'language': {'ar':'اللغة','fr':'Langue','en':'Language','es':'Idioma','tr':'Dil','de':'Sprache','ru':'Язык'},
      'chooseLanguage': {'ar':'اختيار لغة التطبيق','fr':'Choisir la langue','en':'Choose app language','es':'Elegir idioma','tr':'Uygulama dilini seç','de':'App-Sprache wählen','ru':'Выберите язык приложения'},
      'languageSubtitle': {'ar':'العربية والفرنسية والإنجليزية ولغات أخرى','fr':'Arabe, français, anglais et autres langues','en':'Arabic, French, English and more','es':'Árabe, francés, inglés y más','tr':'Arapça, Fransızca, İngilizce ve daha fazlası','de':'Arabisch, Französisch, Englisch und mehr','ru':'Арабский, французский, английский и другие'},
      'appearance': {'ar':'مظهر SocialNova','fr':'Apparence SocialNova','en':'SocialNova appearance','es':'Apariencia de SocialNova','tr':'SocialNova görünümü','de':'SocialNova Erscheinungsbild','ru':'Внешний вид SocialNova'},
      'neon': {'ar':'Neon Glass','fr':'Neon Glass','en':'Neon Glass','es':'Neon Glass','tr':'Neon Glass','de':'Neon Glass','ru':'Neon Glass'},
      'night': {'ar':'الوضع الداكن الليلي','fr':'Mode sombre nocturne','en':'Night dark mode','es':'Modo oscuro nocturno','tr':'Gece karanlık modu','de':'Nacht-Dunkelmodus','ru':'Ночной тёмный режим'},
      'save': {'ar':'حفظ','fr':'Enregistrer','en':'Save','es':'Guardar','tr':'Kaydet','de':'Speichern','ru':'Сохранить'},
      'cancel': {'ar':'إلغاء','fr':'Annuler','en':'Cancel','es':'Cancelar','tr':'İptal','de':'Abbrechen','ru':'Отмена'},
    };
    return m[key]?[code] ?? m[key]?['en'] ?? key;
  }
  static String t(String source,[String? code]) {
    final c=code??AppLocale.locale.value.languageCode;
    if(c=='ar') return source;
    return _common[source]?[c] ?? source;
  }
  static const Map<String,Map<String,String>> _common={
    'كتم الصوت': {'fr':'Muet','en':'Mute','es':'Silencio','tr':'Sessiz','de':'Stumm','ru':'Без звука'},
    'مكبر الصوت': {'fr':'Haut-parleur','en':'Speaker','es':'Altavoz','tr':'Hoparlör','de':'Lautsprecher','ru':'Динамик'},
    'مشاركة': {'fr':'Partager','en':'Share','es':'Compartir','tr':'Paylaş','de':'Teilen','ru':'Поделиться'},
    'الإعدادات': {'fr':'Paramètres','en':'Settings','es':'Ajustes','tr':'Ayarlar','de':'Einstellungen','ru':'Настройки'}, 'اللغة': {'fr':'Langue','en':'Language','es':'Idioma','tr':'Dil','de':'Sprache','ru':'Язык'}, 'حفظ': {'fr':'Enregistrer','en':'Save','es':'Guardar','tr':'Kaydet','de':'Speichern','ru':'Сохранить'}, 'إلغاء': {'fr':'Annuler','en':'Cancel','es':'Cancelar','tr':'İptal','de':'Abbrechen','ru':'Отмена'}, 'تأكيد': {'fr':'Confirmer','en':'Confirm','es':'Confirmar','tr':'Onayla','de':'Bestätigen','ru':'Подтвердить'}, 'إعادة المحاولة': {'fr':'Réessayer','en':'Retry','es':'Reintentar','tr':'Tekrar dene','de':'Erneut versuchen','ru':'Повторить'}, 'الكل': {'fr':'Tout','en':'All','es':'Todo','tr':'Tümü','de':'Alle','ru':'Все'}, 'الرئيسية': {'fr':'Accueil','en':'Home','es':'Inicio','tr':'Ana Sayfa','de':'Startseite','ru':'Главная'}, 'استكشاف': {'fr':'Explorer','en':'Explore','es':'Explorar','tr':'Keşfet','de':'Entdecken','ru':'Обзор'}, 'إنشاء': {'fr':'Créer','en':'Create','es':'Crear','tr':'Oluştur','de':'Erstellen','ru':'Создать'}, 'حسابي': {'fr':'Mon profil','en':'My profile','es':'Mi perfil','tr':'Profilim','de':'Mein Profil','ru':'Мой профиль'}, 'الرسائل': {'fr':'Messages','en':'Messages','es':'Mensajes','tr':'Mesajlar','de':'Nachrichten','ru':'Сообщения'}, 'الإشعارات': {'fr':'Notifications','en':'Notifications','es':'Notificaciones','tr':'Bildirimler','de':'Benachrichtigungen','ru':'Уведомления'}, 'المجموعات': {'fr':'Groupes','en':'Groups','es':'Grupos','tr':'Gruplar','de':'Gruppen','ru':'Группы'}, 'المتابعون': {'fr':'Abonnés','en':'Followers','es':'Seguidores','tr':'Takipçiler','de':'Follower','ru':'Подписчики'}, 'متابعة': {'fr':'Suivre','en':'Follow','es':'Seguir','tr':'Takip et','de':'Folgen','ru':'Подписаться'}, 'يتابع': {'fr':'Abonné','en':'Following','es':'Siguiendo','tr':'Takip ediyor','de':'Folgt','ru':'Подписки'}, 'منشورات': {'fr':'Publications','en':'Posts','es':'Publicaciones','tr':'Gönderiler','de':'Beiträge','ru':'Публикации'}, 'منشور': {'fr':'Publication','en':'Post','es':'Publicación','tr':'Gönderi','de':'Beitrag','ru':'Пост'}, 'المنشور': {'fr':'Publication','en':'Post','es':'Publicación','tr':'Gönderi','de':'Beitrag','ru':'Публикация'}, 'الريلز': {'fr':'Reels','en':'Reels','es':'Reels','tr':'Reels','de':'Reels','ru':'Reels'}, 'الستوري': {'fr':'Story','en':'Story','es':'Historia','tr':'Hikâye','de':'Story','ru':'История'}, 'التعليقات': {'fr':'Commentaires','en':'Comments','es':'Comentarios','tr':'Yorumlar','de':'Kommentare','ru':'Комментарии'}, 'رد': {'fr':'Répondre','en':'Reply','es':'Responder','tr':'Yanıtla','de':'Antworten','ru':'Ответить'}, 'إعادة نشر': {'fr':'Republier','en':'Repost','es':'Republicar','tr':'Yeniden paylaş','de':'Erneut posten','ru':'Репост'}, 'الخصوصية': {'fr':'Confidentialité','en':'Privacy','es':'Privacidad','tr':'Gizlilik','de':'Datenschutz','ru':'Конфиденциальность'}, 'الجمهور': {'fr':'Audience','en':'Audience','es':'Público','tr':'Hedef kitle','de':'Zielgruppe','ru':'Аудитория'}, 'عام': {'fr':'Public','en':'Public','es':'Público','tr':'Herkese açık','de':'Öffentlich','ru':'Публичный'}, 'عامة': {'fr':'Public','en':'Public','es':'Público','tr':'Herkese açık','de':'Öffentlich','ru':'Публичная'}, 'الخاصة': {'fr':'Privé','en':'Private','es':'Privado','tr':'Özel','de':'Privat','ru':'Приватный'}, 'المتابعون فقط': {'fr':'Abonnés uniquement','en':'Followers only','es':'Solo seguidores','tr':'Yalnızca takipçiler','de':'Nur Follower','ru':'Только подписчики'}, 'أصدقاء محددون': {'fr':'Amis sélectionnés','en':'Selected friends','es':'Amigos seleccionados','tr':'Seçili arkadaşlar','de':'Ausgewählte Freunde','ru':'Выбранные друзья'}, 'الأصدقاء المقربون': {'fr':'Amis proches','en':'Close friends','es':'Amigos cercanos','tr':'Yakın arkadaşlar','de':'Enge Freunde','ru':'Близкие Freunde'}, 'حذف': {'fr':'Supprimer','en':'Delete','es':'Eliminar','tr':'Sil','de':'Löschen','ru':'Удалить'}, 'تعديل': {'fr':'Modifier','en':'Edit','es':'Editar','tr':'Düzenle','de':'Bearbeiten','ru':'Изменить'}, 'تعديل المحتوى': {'fr':'Modifier le contenu','en':'Edit content','es':'Editar contenido','tr':'İçeriği düzenle','de':'Inhalt bearbeiten','ru':'Изменить контент'}, 'النص': {'fr':'Texte','en':'Text','es':'Texto','tr':'Metin','de':'Text','ru':'Текст'}, 'الموسيقى': {'fr':'Musique','en':'Music','es':'Música','tr':'Müzik','de':'Musik','ru':'Музыка'}, 'الإحصائيات': {'fr':'Statistiques','en':'Analytics','es':'Estadísticas','tr':'İstatistikler','de':'Statistiken','ru':'Статистика'}, 'المشاهدات': {'fr':'Vues','en':'Views','es':'Vistas','tr':'Görüntülenme','de':'Aufrufe','ru':'Просмотры'}, 'الإعجابات': {'fr':'J’aime','en':'Likes','es':'Me gusta','tr':'Beğeniler','de':'Likes','ru':'Лайки'}, 'المشاركات': {'fr':'Partages','en':'Shares','es':'Compartidos','tr':'Paylaşımlar','de':'Geteilt','ru':'Репосты'}, 'نشر الآن': {'fr':'Publier maintenant','en':'Publish now','es':'Publicar ahora','tr':'Şimdi yayınla','de':'Jetzt veröffentlichen','ru':'Опубликовать сейчас'}, 'حفظ كمسودة': {'fr':'Enregistrer comme brouillon','en':'Save as draft','es':'Guardar como borrador','tr':'Taslak olarak kaydet','de':'Als Entwurf speichern','ru':'Сохранить как чер稿'}, 'جدولة النشر': {'fr':'Planifier la publication','en':'Schedule post','es':'Programar publicación','tr':'Yayınlamayı planla','de':'Veröffentlichung planen','ru':'Запланировать публикацию'}, 'الجدولة': {'fr':'Planification','en':'Scheduling','es':'Programación','tr':'Zamanlama','de':'Planung','ru':'Планирование'}, 'التعليقات متوقفة': {'fr':'Commentaires désactivés','en':'Comments are off','es':'Comentarios desactivados','tr':'Yorumlar kapalı','de':'Kommentare deaktiviert','ru':'Комментарии отключены'}, 'السماح بالتعليقات': {'fr':'Autoriser les commentaires','en':'Allow comments','es':'Permitir comentarios','tr':'Yorumlara izin ver','de':'Kommentare erlauben','ru':'Разрешить комментарии'}, 'السماح بالردود': {'fr':'Autoriser les réponses','en':'Allow replies','es':'Permitir respuestas','tr':'Yanıtlara izin ver','de':'Antworten erlauben','ru':'Разрешить ответы'}, 'طلبات المراسلة': {'fr':'Demandes de messages','en':'Message requests','es':'Solicitudes de mensajes','tr':'Mesaj istekleri','de':'Nachrichtenanfragen','ru':'Запросы на сообщения'}, 'إعدادات المحادثة': {'fr':'Paramètres de discussion','en':'Chat settings','es':'Ajustes del chat','tr':'Sohbet ayarları','de':'Chat-Einstellungen','ru':'Настройки чата'}, 'تغيير خلفية المحادثة': {'fr':'Changer le fond de la discussion','en':'Change chat background','es':'Cambiar fondo del chat','tr':'Sohbet arka planını değiştir','de':'Chat-Hintergrund ändern','ru':'Изменить фон чата'}, 'لا توجد محادثات بعد': {'fr':'Aucune conversation pour le moment','en':'No conversations yet','es':'Aún no hay conversaciones','tr':'Henüz sohbet yok','de':'Noch keine Chats','ru':'Пока нет чатов'}, 'إرسال': {'fr':'Envoyer','en':'Send','es':'Enviar','tr':'Gönder','de':'Senden','ru':'Отправить'}, 'بحث': {'fr':'Rechercher','en':'Search','es':'Buscar','tr':'Ara','de':'Suchen','ru':'Поиск'}, 'إنشاء حساب': {'fr':'Créer un compte','en':'Create account','es':'Crear cuenta','tr':'Hesap oluştur','de':'Konto erstellen','ru':'Создать аккаунт'}, 'تسجيل الدخول': {'fr':'Se connecter','en':'Log in','es':'Iniciar sesión','tr':'Giriş yap','de':'Anmelden','ru':'Войти'}, 'الاسم الكامل': {'fr':'Nom complet','en':'Full name','es':'Nombre completo','tr':'Ad soyad','de':'Vollständiger Name','ru':'Полное имя'}, 'اسم المستخدم': {'fr':"Nom d’utilisateur",'en':'Username','es':'Nombre de usuario','tr':'Kullanıcı adı','de':'Benutzername','ru':'Имя пользователя'}, 'كلمة المرور': {'fr':'Mot de passe','en':'Password','es':'Contraseña','tr':'Şifre','de':'Passwort','ru':'Пароль'}, 'تاريخ الميلاد': {'fr':'Date de naissance','en':'Date of birth','es':'Fecha de nacimiento','tr':'Doğum tarihi','de':'Geburtsdatum','ru':'Дата рождения'}, 'الجنس': {'fr':'Sexe','en':'Gender','es':'Género','tr':'Cinsiyet','de':'Geschlecht','ru':'Пол'}, 'ذكر': {'fr':'Homme','en':'Male','es':'Hombre','tr':'Erkek','de':'Männlich','ru':'Мужской'}, 'أنثى': {'fr':'Femme','en':'Female','es':'Mujer','tr':'Kadın','de':'Weiblich','ru':'Женский'}, 'الموقع': {'fr':'Emplacement','en':'Location','es':'Ubicación','tr':'Konum','de':'Standort','ru':'Местоположение'}, 'الوصف': {'fr':'Description','en':'Description','es':'Descripción','tr':'Açıklama','de':'Beschreibung','ru':'Описание'}, 'عنوان': {'fr':'Titre','en':'Title','es':'Título','tr':'Başlık','de':'Titel','ru':'Заголовок'}, 'هدية': {'fr':'Cadeau','en':'Gift','es':'Regalo','tr':'Hediye','de':'Geschenk','ru':'Подарок'}, 'إرسال هدية': {'fr':'Envoyer un cadeau','en':'Send gift','es':'Enviar regalo','tr':'Hediye gönder','de':'Geschenk senden','ru':'Отправить подарок'}, 'الآن': {'fr':'À l’instant','en':'Just now','es':'Ahora','tr':'Şimdi','de':'Gerade eben','ru':'Только что'}, 'لا توجد تعليقات بعد': {'fr':'Aucun commentaire pour le moment','en':'No comments yet','es':'Aún no hay comentarios','tr':'Henüz yorum yok','de':'Noch keine Kommentare','ru':'Комментариев пока нет'}, 'أرشفة': {'fr':'Archiver','en':'Archive','es':'Archivar','tr':'Arşivle','de':'Archivieren','ru':'Архивировать'}, 'تثبيت المنشور': {'fr':'Épingler la publication','en':'Pin post','es':'Fijar publicación','tr':'Gönderiyi sabitle','de':'Beitrag anheften','ru':'Закрепить публикацию'}, 'تثبيت في البروفايل': {'fr':'Épingler au profil','en':'Pin to profile','es':'Fijar en el perfil','tr':'Profile sabitle','de':'Im Profil anheften','ru':'Закрепить в профиле'}, 'تحديد الجمهور': {'fr':'Choisir l’audience','en':'Choose audience','es':'Elegir audiencia','tr':'Hedef kitleyi seç','de':'Zielgruppe wählen','ru':'Выбрать аудиторию'}, 'اختر أشخاصًا محددين': {'fr':'Choisir des personnes spécifiques','en':'Choose specific people','es':'Elegir personas específicas','tr':'Belirli kişileri seç','de':'Bestimmte Personen auswählen','ru':'Выбрать конкретных людей'},
  };

}
