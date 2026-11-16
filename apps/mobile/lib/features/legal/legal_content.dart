import "../../core/app_config.dart";

class LegalSection {
  const LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({required this.title, required this.intro, required this.sections});

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

/// Plain-language privacy policy that matches what the app actually does.
/// DRAFT: the owner (ideally a lawyer) must review it before release, then set
/// LEGAL_REVIEWED=true. Keep it in step with the code: if a new kind of data is
/// collected, update this and the store data-safety forms.
LegalDocument buildPrivacyPolicy() {
  final operator = AppConfig.operatorLabel;
  final contact = AppConfig.supportLabel;
  return LegalDocument(
    title: "Privacy policy",
    intro:
        "${AppConfig.appName} helps travelers landing at the same airport find each other to share a cab. "
        "This policy explains what we collect, why, who sees it and how you can delete it.",
    sections: [
      LegalSection("Who runs this app", [
        "$operator runs ${AppConfig.appName} (\"we\"). You can reach us at $contact.",
      ]),
      const LegalSection("What we collect", [
        "Account: your email address, used to sign you in with one-time codes.",
        "Profile: your name, gender, matching preference (anyone, or same gender only), profile photo, optional bio and your mobile number.",
        "Trips: the flight number you enter or scan, when you plan to leave the airport, and the area you are heading to.",
        "Matching: the people you like or pass on, your matches and how they end.",
        "Messages: what you send in a chat with a match.",
        "Safety and feedback: ratings you give, reports and blocks, and feedback you send us.",
        "Technical: login codes (short-lived), crash reports, and basic usage information (for example that you opened the app, signed up, made a ride request or a match). This is tied to a random identifier, never to your name, email, phone number or message text. You can turn off the crash reports and app-opened signal in Settings.",
      ]),
      const LegalSection("What we do not collect", [
        "We do not read your device location, contacts or payment details. We never handle payments or bookings.",
        "When you scan a boarding pass, the barcode is read on your device and only the flight number and date are used. The picture is not uploaded.",
      ]),
      const LegalSection("What other people see", [
        "People you could be matched with see your name, photo, bio, destination area, planned departure time, flight number and rating.",
        "Your email address and mobile number are never shown to other users. Your mobile number is kept for safety and records only.",
        "Messages are visible to you and the person you are matched with.",
      ]),
      const LegalSection("How we use your information", [
        "To run the service: sign you in, suggest people travelling your way, enable chat, and keep ratings, reports and blocks working.",
        "To keep people safe: review reports, remove accounts that break the rules, and respond to legal requests.",
        "To improve the app: fix errors and understand which parts are used, without identifying you.",
      ]),
      const LegalSection("Who we share it with", [
        "We use trusted service providers to run the app: hosting and file storage (Vercel), our database (Neon), email delivery (Resend), live chat updates (Pusher), and, to understand usage and fix crashes, a product analytics service and an error-tracking service that receive only the random identifier and the technical details described above. They process data for us under their own terms and may store it outside India.",
        "We do not sell your information and we do not use it for advertising.",
        "We may disclose information if the law requires it or to protect someone's safety.",
      ]),
      const LegalSection("How long we keep it", [
        "We keep your information while your account exists. When you delete your account we immediately delete your profile, photo, trips, matches, messages, ratings, reports, feedback, blocks and login codes. Copies can remain in provider backups for a short, limited time.",
        "Reports filed against a person are deleted with that person's account.",
      ]),
      LegalSection("Your choices and rights", [
        "You can see and edit your profile in the app, and delete your account in Settings or at ${AppConfig.webAppUrl}/#/delete-account.",
        "To ask for a copy of your data or to correct or erase something the app does not let you change, contact $contact.",
        "Grievance officer: ${AppConfig.grievanceLabel}. We aim to respond within the time the law requires.",
      ]),
      const LegalSection("Age", [
        "The app is for people aged 18 and over. We do not knowingly collect data from anyone younger.",
      ]),
      const LegalSection("Changes", [
        "If we change this policy in a way that matters we will tell you in the app before it takes effect.",
      ]),
    ],
  );
}

/// Terms of service. DRAFT, same review rules as the privacy policy.
LegalDocument buildTerms() {
  final operator = AppConfig.operatorLabel;
  final contact = AppConfig.supportLabel;
  return LegalDocument(
    title: "Terms of service",
    intro:
        "By using ${AppConfig.appName} you agree to these terms. They are written to be read: please do.",
    sections: [
      LegalSection("What we do", [
        "$operator provides an app that introduces travelers heading the same way so they can choose to share a cab.",
        "We are not a taxi, ride-hailing or transport company. You book and pay for any ride yourself (for example with Uber, Ola or Rapido). We never handle payments, fares or bookings.",
      ]),
      const LegalSection("Who can use it", [
        "You must be 18 or older, and the details you give must be true. One account per person, and your profile photo must be a photo of you.",
        "Keep access to your email secure. You are responsible for what happens on your account.",
      ]),
      const LegalSection("Meeting safely", [
        "Meeting a stranger carries risk. Always meet at the official airport pickup zone in a public, well-lit place, check that the person matches their profile photo, and never share a cab if something feels wrong.",
        "We do not verify identities beyond email, and we cannot guarantee anyone's behaviour. Decisions to meet, travel together or split costs are yours.",
      ]),
      const LegalSection("Rules", [
        "Be respectful. Do not harass, threaten, discriminate against or pressure anyone, send abusive or sexual messages, pretend to be someone else, post illegal content, promote services, or misuse the app or other people's information.",
        "Do not try to break, overload or reverse-engineer the service.",
      ]),
      const LegalSection("Your content", [
        "You keep ownership of what you post. You allow us to store and show it to the people you are matched with, as needed to run the service.",
      ]),
      LegalSection("Reports, blocks and removal", [
        "You can report or block anyone from a chat. We review every report, aiming to do so within 48 hours, and may remove content or suspend or delete accounts that break these rules, with or without notice where safety is at risk.",
        "To report a concern, use the report option in a chat or contact $contact.",
      ]),
      const LegalSection("The service", [
        "We try to keep the app available but do not promise it will always work or that you will find a match. We may change or stop features.",
      ]),
      LegalSection("Responsibility", [
        "To the extent the law allows, we are not responsible for what users do, for rides or journeys, or for losses that come from using the app. Nothing in these terms limits liability that cannot be limited by law.",
        "These terms are governed by the laws of ${AppConfig.governingLaw}, and the courts there can decide disputes.",
      ]),
      const LegalSection("Ending your use", [
        "You can stop at any time and delete your account in Settings. We may suspend or end your access if you break these terms.",
      ]),
      const LegalSection("Changes and contact", [
        "We may update these terms and will tell you in the app about changes that matter. Questions: see the contact details in the privacy policy.",
      ]),
    ],
  );
}
