// Wygenerowane przez tool/i18n/generate.py z tool/i18n/guide.py — nie edytuj ręcznie.

class GuideItem {
  const GuideItem(this.question, this.answer, {this.important = false, this.advanced = false});
  final String question;
  final String answer;
  final bool important;
  final bool advanced;
}

class GuideSection {
  const GuideSection(this.id, this.title, this.items);
  final String id;
  final String title;
  final List<GuideItem> items;
}

class Guide {
  const Guide(this.intro, this.importantLabel, this.advancedLabel, this.sections);
  final String intro;
  final String importantLabel;
  final String advancedLabel;
  final List<GuideSection> sections;
}

const guides = <String, Guide>{
  'pl': Guide(
    'Ogólny przewodnik: jak bezpiecznie korzystać z RemoteAppTester i rozwijać aplikacje z agentami AI. Narzędzia i zasady szybko się zmieniają — zanim coś wdrożysz, sprawdź aktualne rozwiązanie razem z czatem AI (np. Claude, ChatGPT) i w oficjalnej dokumentacji.',
    'Ważne',
    'Zaawansowane',
    [
      GuideSection('start', 'Jak działa ta aplikacja', [
        GuideItem('Co robi RemoteAppTester?', 'Buduje aplikację z wybranego folderu na Twoim komputerze lub serwerze i dostarcza ją na telefon testowy. Telefon jest pilotem: zleca buildy, instaluje i uruchamia wersje. Nic nie przechodzi przez serwery RemoteAppTester, bo takich nie ma.'),
        GuideItem('Jak wygląda typowy dzień pracy?', '• Agent AI wprowadza zmiany w folderze projektu.\n• Po pracy wysyła sygnał (plik .remoteapptester-signal albo rt sg).\n• RemoteAppTester buduje zatwierdzonymi komendami.\n• Telefon pyta o instalację, potem uruchamia nową wersję.\n• Testujesz i wracasz do agenta z uwagami.'),
      ]),
      GuideSection('security', 'Bezpieczne korzystanie', [
        GuideItem('Co jest już zabezpieczone?', '• Połączenie tylko przez prywatną sieć Tailscale, z certyfikatem przypiętym przy parowaniu i podpisem każdego żądania.\n• Komendy budowania w zaszyfrowanej bazie.\n• Telefon nie wysyła komend ani ścieżek.\n• Kod parowania jest jednorazowy, a sekret telefonu zmienia się co 30 dni.'),
        GuideItem('Tailscale: co koniecznie ustawić?', '• Reguły dostępu (grants/ACL): do portu RemoteAppTester (domyślnie 47051) tylko Twoje telefony.\n• Tailnet Lock: nowe urządzenie dołącza dopiero po podpisaniu przez Twoje zaufane urządzenia, więc nawet serwer koordynacji Tailscale nie doda go sam.\n• Wygasanie kluczy urządzeń (domyślnie 180 dni) zostaw włączone; wyłączaj tylko dla serwera i świadomie.\n• Włącz logowanie dwuskładnikowe na koncie Tailscale.\nDokładne kroki sprawdź w dokumentacji Tailscale i z czatem AI.', important: true),
        GuideItem('Kod parowania', 'Kod QR daje dostęp do komputera. Jest jednorazowy i ważny 1 godzinę, ale do czasu użycia traktuj go jak hasło. Nie rób mu zdjęć i nie wysyłaj komunikatorem. Zgubiony telefon odwołaj od razu w zakładce Telefony; pozostałe działają dalej.'),
        GuideItem('Czy logi są bezpieczne?', 'Przed wysłaniem na telefon logi są filtrowane z typowych haseł, tokenów i nazwy użytkownika. To filtr wzorców, więc nie złapie wszystkiego. Nie wypisuj sekretów w skryptach budowania.'),
      ]),
      GuideSection('risks', 'Najważniejsze ryzyka', [
        GuideItem('Agent AI na moim koncie Windows', 'Agent uruchomiony bezpośrednio na Twoim koncie ma dostęp do wszystkiego, do czego masz Ty: plików, haseł w przeglądarce, kluczy SSH, a także danych RemoteAppTester. Szyfrowanie DPAPI nie chroni przed programem działającym jako Ty. Bezpieczniej: sandbox (sekcja niżej).', important: true),
        GuideItem('Build uruchamia kod z projektu', 'Zatwierdzone komendy to nie wszystko: Gradle i inne narzędzia wykonują skrypty z repozytorium. Jeśli agent jest w sandboksie, a build działa na głównym komputerze, agent może tą drogą uruchomić kod poza sandboksem. Zasada: buduj tam, gdzie pracuje agent.', important: true),
        GuideItem('Niesprawdzona aplikacja na telefonie', 'Testowana aplikacja zawiera kod, którego mogłeś nie przeczytać, i dostaje zwykłe uprawnienia. Najlepiej używaj osobnego telefonu testowego bez prywatnych danych albo profilu służbowego. Dlatego domyślny tryb to „Pytaj na telefonie”.', important: true),
        GuideItem('Prompt injection, czyli wstrzyknięte polecenia', 'Agent czyta strony WWW, zgłoszenia i pliki. Ukryte w nich polecenia mogą nakłonić go do kradzieży danych albo dodania złośliwego kodu. Ogranicz dostęp do sieci i sekretów, a zmiany przeglądaj przed uruchomieniem.'),
        GuideItem('Fałszywe pakiety i zależności', 'Agent może dodać bibliotekę o nazwie podobnej do prawdziwej albo taką, która nie istnieje i została przejęta. Sprawdzaj nowe zależności, pilnuj pliku blokady wersji i używaj skanera podatności.', advanced: true),
      ]),
      GuideSection('agents', 'Agenci AI: instalacja i praca', [
        GuideItem('Jak zainstalować agenta?', '• Pobieraj tylko z oficjalnej strony producenta (np. Claude Code, Codex, rozszerzenia VS Code).\n• Najlepiej zainstaluj go w sandboksie, nie na głównym koncie.\n• Zaloguj się kontem z włączonym logowaniem dwuskładnikowym.\n• Wtyczki i serwery MCP dodawaj tylko zaufane, bo mają takie uprawnienia jak agent.\nAktualną procedurę sprawdź z czatem AI.'),
        GuideItem('Jakie uprawnienia dać agentowi?', 'Najmniejsze, które wystarczą: tylko folder projektu, polecenia zatwierdzane przez Ciebie, bez trybu „pomijaj wszystkie pytania” na głównym koncie. Tryb w pełni automatyczny zostaw do sandboksu.'),
        GuideItem('Sekrety a agent', 'Nie zapisuj haseł, kluczy API ani klucza podpisu w repozytorium ani w plikach czytanych przez agenta. Daj agentowi osobne tokeny o wąskim zakresie i krótkiej ważności. Treść rozmowy z agentem może trafić do dostawcy modelu, więc sprawdź jego zasady prywatności.', important: true),
        GuideItem('Jak pracować z agentem nad projektem?', '• Git od pierwszego dnia: osobna gałąź na zadanie, małe commity.\n• Dawaj jedno małe zadanie naraz z opisem, po czym poznać, że działa.\n• Przeglądaj zmiany, zwłaszcza skrypty budowania i zależności.\n• Proś o testy i uruchamiaj je przed instalacją.\n• Propozycje komend w zakładce Komendy czytaj przed zatwierdzeniem.\n• Rób kopie zapasowe poza maszyną agenta.'),
        GuideItem('Agent sam buduje aplikację — jak wysłać ją na telefon?', 'W folderze projektu agent uruchamia: rt push <plik.apk> -m "co zmieniono" --wait --json\n• Bez sudo i bez dostępu do RemoteAppTestera: polecenie zostawia sygnał w folderze projektu.\n• Przyjmowany jest tylko podpisany plik .apk z folderu projektu (plik spoza folderu jest tam kopiowany).\n• Instalacja na telefonie według opcji projektu (np. „zapytaj”).\n• Wynik: kod wyjścia (0 = wysłane) i plik .remoteapptester-status.json, także: rt st.\nWyłączysz to opcją projektu „Agent AI może wysłać własną instalkę” (rt o --agent-push off).'),
        GuideItem('Czy mogę ufać temu, co napisał agent?', 'Traktuj to jak kod nowego współpracownika: bywa świetny, ale bywa błędny lub niebezpieczny. Za aplikację odpowiadasz Ty. Logowanie, płatności i dane użytkowników wymagają szczególnie uważnego przeglądu.'),
      ]),
      GuideSection('sandbox', 'Sandbox: praca w izolacji', [
        GuideItem('Po co sandbox?', 'Agent, jego narzędzia i build działają wtedy w oddzielnym systemie. Błąd lub atak obejmuje tylko to środowisko, a nie Twoje pliki, hasła i konta. Można je przywrócić do czystego stanu.', important: true),
        GuideItem('Które rozwiązanie wybrać?', '• Maszyna wirtualna (Hyper-V, VirtualBox, VMware): dobra izolacja i migawki; najlepszy wybór do stałej pracy.\n• Osobny komputer lub VPS: najmocniejsza izolacja; RemoteAppTester ma wersję na Linuxa.\n• Windows Sandbox (Pro/Enterprise): szybki, ale kasuje się po zamknięciu; do krótkich prób.\n• Dev Container/Docker: wygodny, słabsza izolacja, zwłaszcza z podłączonymi folderami.\n• WSL2: domyślnie widzi dyski Windows, więc sam w sobie nie jest barierą.\n• Osobne konto Windows: proste, ale izolacja najsłabsza.'),
        GuideItem('Jak to ustawić krok po kroku?', '1. Utwórz maszynę wirtualną z czystym systemem i osobnym kontem.\n2. Zainstaluj w niej agenta, narzędzia budowania i RemoteAppTester oraz Tailscale.\n3. Sklonuj repozytorium do maszyny; nie podłączaj folderów z głównego komputera.\n4. Użyj osobnych tokenów o wąskim zakresie, bez prywatnych haseł.\n5. Sparuj telefon bezpośrednio z tą maszyną, wtedy build działa w izolacji.\n6. Zrób migawkę czystego stanu i wracaj do niej po ryzykownej pracy.\nKonkretne polecenia dla swojego systemu przygotuj z czatem AI.'),
        GuideItem('Na co uważać w sandboksie?', '• Podłączony folder z głównego komputera to dziura w izolacji: agent może zmienić skrypty, które uruchomisz poza sandboksem.\n• Schowek i przeciąganie plików między systemami lepiej wyłączyć.\n• Ogranicz ruch sieciowy maszyny; niech nie widzi Twojej sieci domowej.\n• W Tailscale nadaj maszynie osobny tag i wąskie reguły.\n• Aktualizuj system w maszynie tak samo jak główny.', important: true, advanced: true),
      ]),
      GuideSection('phone', 'Telefon testowy', [
        GuideItem('Dlaczego telefon pyta o instalację?', 'Android wymaga zgody na instalację z innego źródła niż sklep, a część producentów (np. HyperOS) pyta przy każdej aktualizacji. To ochrona, nie błąd. Nie wyłączaj zabezpieczeń telefonu ani Play Protect, żeby to obejść.'),
        GuideItem('Wersje debug a wydanie', 'Do codziennych testów służy wersja debug: buduj ją tylko pod architekturę telefonu (np. --target-platform android-arm64), bo będzie mniejsza. Nie udostępniaj jej innym i nie publikuj. Przed publikacją testuj wersję release.'),
      ]),
      GuideSection('publish', 'Publikacja aplikacji', [
        GuideItem('Od czego zacząć publikację?', 'Zasady sklepów często się zmieniają, więc najpierw zbadaj temat razem z czatem AI: wymagania sklepu, dokumenty, koszty, prawo w krajach sprzedaży. Sprawdź wszystko w oficjalnej dokumentacji; czat może mieć nieaktualne dane.', important: true),
        GuideItem('Klucz podpisu', 'Każda aplikacja musi mieć własny klucz wydania, inny niż klucz debug. W Google Play zwykle używa się Play App Signing: Google przechowuje klucz aplikacji, a Ty masz klucz przesyłania. Klucza nigdy nie dodawaj do repozytorium ani nie pokazuj agentowi; trzymaj kopię w bezpiecznym miejscu.', important: true),
        GuideItem('Google Play: wymagania', '• Konto osobiste założone po 13.11.2023: przed produkcją test zamknięty z co najmniej 12 testerami przez 14 dni.\n• Polityka prywatności i formularz bezpieczeństwa danych.\n• Wrażliwe uprawnienia wymagają deklaracji i uzasadnienia.\n• Identyfikatora aplikacji nie zmienisz po publikacji.\nSprawdź aktualny stan w Play Console.'),
        GuideItem('Instalacja poza sklepem i weryfikacja deweloperów', 'Google wprowadza weryfikację deweloperów dla aplikacji instalowanych na certyfikowanych urządzeniach, także spoza sklepu: od 30.09.2026 w Brazylii, Indonezji, Singapurze i Tajlandii, globalnie od 2027. Terminy i wyjątki sprawdź przed wydaniem, bo mogą wpłynąć też na testy aplikacji poza sklepem.', important: true),
        GuideItem('Bezpieczeństwo przed wydaniem', '• Usuń logi diagnostyczne i klucze testowe.\n• Sprawdź zależności skanerem podatności.\n• Poproś czat AI o niezależny przegląd bezpieczeństwa, a przy danych wrażliwych także specjalistę.\n• Sprawdź, jakie dane zbiera aplikacja i na jakiej podstawie (RODO).'),
      ]),
      GuideSection('decisions', 'Decyzje, które musisz podjąć', [
        GuideItem('Lista do przemyślenia', '• Gdzie działa agent: na głównym koncie czy w sandboksie?\n• Czy sygnał agenta ma sam budować? Bezpiecznie tylko wtedy, gdy build jest w izolacji.\n• Instalować automatycznie czy pytać na telefonie?\n• Telefon testowy: osobny czy prywatny?\n• Jakie sekrety i konta wolno widzieć agentowi?\n• Kto i kiedy przegląda zmiany?\n• Gdzie są kopie zapasowe i klucz podpisu?\n• Czy dane projektu mogą trafiać do dostawcy modelu AI?\nNiepewne punkty omów z czatem AI, podając swój konkretny przypadek.', important: true),
      ]),
    ],
  ),
  'en': Guide(
    'A general guide: how to use RemoteAppTester safely and develop apps with AI agents. Tools and rules change quickly — before you apply anything, check the current solution with an AI chat (e.g. Claude, ChatGPT) and the official documentation.',
    'Important',
    'Advanced',
    [
      GuideSection('start', 'How this app works', [
        GuideItem('What does RemoteAppTester do?', 'It builds an app from a chosen folder on your computer or server and delivers it to a test phone. The phone is a remote: it starts builds, installs and launches versions. Nothing goes through RemoteAppTester servers, because there are none.'),
        GuideItem('What does a typical working day look like?', '• An AI agent changes the project folder.\n• After work it sends a signal (the .remoteapptester-signal file or rt sg).\n• RemoteAppTester builds with approved commands.\n• The phone asks to install, then launches the new version.\n• You test and return to the agent with feedback.'),
      ]),
      GuideSection('security', 'Using it safely', [
        GuideItem('What is already protected?', '• Connection only through the private Tailscale network, with a certificate pinned at pairing and every request signed.\n• Build commands in an encrypted database.\n• The phone sends no commands or paths.\n• The pairing code is single-use and the phone secret changes every 30 days.'),
        GuideItem('Tailscale: what must you set up?', '• Access rules (grants/ACL): only your phones may reach the RemoteAppTester port (47051 by default).\n• Tailnet Lock: a new device joins only after your trusted devices sign it, so even the Tailscale coordination server cannot add one by itself.\n• Keep device key expiry on (180 days by default); turn it off only for a server and on purpose.\n• Enable two-factor sign-in on your Tailscale account.\nCheck the exact steps in the Tailscale docs and with an AI chat.', important: true),
        GuideItem('The pairing code', 'The QR code gives access to the computer. It is single-use and valid for 1 hour, but until used treat it like a password. Do not photograph it or send it by messenger. Revoke a lost phone at once on the Phones tab; the others keep working.'),
        GuideItem('Are logs safe?', 'Before reaching the phone, logs are filtered for typical passwords, tokens and the user name. It is a pattern filter, so it will not catch everything. Do not print secrets in build scripts.'),
      ]),
      GuideSection('risks', 'The main risks', [
        GuideItem('An AI agent on my Windows account', 'An agent run directly on your account can reach everything you can: files, browser passwords, SSH keys and RemoteAppTester data too. DPAPI encryption does not protect against a program running as you. Safer: a sandbox (section below).', important: true),
        GuideItem('A build runs code from the project', 'Approved commands are not everything: Gradle and other tools run scripts from the repository. If the agent is sandboxed but the build runs on your main computer, the agent can use this to run code outside the sandbox. Rule: build where the agent works.', important: true),
        GuideItem('Unreviewed app on the phone', 'The tested app contains code you may not have read and gets normal permissions. Preferably use a separate test phone without private data or a work profile. That is why the default mode is “Ask on the phone”.', important: true),
        GuideItem('Prompt injection', 'An agent reads web pages, issues and files. Instructions hidden there can trick it into stealing data or adding malicious code. Limit its network and secret access and review changes before running them.'),
        GuideItem('Fake packages and dependencies', 'An agent may add a library with a look-alike name or one that does not exist and was taken over. Check new dependencies, keep the lock file and use a vulnerability scanner.', advanced: true),
      ]),
      GuideSection('agents', 'AI agents: setup and work', [
        GuideItem('How do I install an agent?', '• Download only from the vendor\'s official site (e.g. Claude Code, Codex, VS Code extensions).\n• Preferably install it in a sandbox, not on your main account.\n• Sign in with an account that has two-factor sign-in.\n• Add only trusted plugins and MCP servers, since they get the agent\'s permissions.\nCheck the current procedure with an AI chat.'),
        GuideItem('What permissions should an agent get?', 'The fewest that work: only the project folder, commands approved by you, and no “skip all prompts” mode on your main account. Keep fully automatic mode for a sandbox.'),
        GuideItem('Secrets and agents', 'Do not store passwords, API keys or the signing key in the repository or in files the agent reads. Give the agent separate tokens with narrow scope and short life. Conversations may reach the model provider, so check its privacy terms.', important: true),
        GuideItem('How do I work on a project with an agent?', '• Git from day one: a branch per task, small commits.\n• Give one small task at a time with a description of how to tell it works.\n• Review changes, especially build scripts and dependencies.\n• Ask for tests and run them before installing.\n• Read command proposals on the Commands tab before approving.\n• Keep backups outside the agent\'s machine.'),
        GuideItem('The agent builds the app itself — how does it reach the phone?', 'In the project folder the agent runs: rt push <file.apk> -m "what changed" --wait --json\n• No sudo and no access to RemoteAppTester: the command leaves a signal in the project folder.\n• Only a signed .apk file from the project folder is accepted (a file from elsewhere is copied there).\n• Installing on the phone follows the project options (e.g. “ask”).\n• Result: exit code (0 = sent) and the .remoteapptester-status.json file, also: rt st.\nTurn it off with the project option “AI agent may send its own installer” (rt o --agent-push off).'),
        GuideItem('Can I trust what the agent wrote?', 'Treat it like code from a new colleague: often great, sometimes wrong or unsafe. You are responsible for the app. Sign-in, payments and user data need especially careful review.'),
      ]),
      GuideSection('sandbox', 'Sandbox: working in isolation', [
        GuideItem('Why a sandbox?', 'The agent, its tools and the build then run in a separate system. A mistake or attack affects only that environment, not your files, passwords and accounts. You can restore it to a clean state.', important: true),
        GuideItem('Which option should I choose?', '• Virtual machine (Hyper-V, VirtualBox, VMware): good isolation and snapshots; the best choice for regular work.\n• Separate computer or VPS: the strongest isolation; RemoteAppTester has a Linux version.\n• Windows Sandbox (Pro/Enterprise): quick, but wiped on close; for short trials.\n• Dev Container/Docker: convenient, weaker isolation, especially with mounted folders.\n• WSL2: sees Windows drives by default, so it is not a barrier by itself.\n• Separate Windows account: simple, but the weakest isolation.'),
        GuideItem('How do I set it up step by step?', '1. Create a virtual machine with a clean system and a separate account.\n2. Install the agent, build tools, RemoteAppTester and Tailscale in it.\n3. Clone the repository into the machine; do not mount folders from your main computer.\n4. Use separate narrow-scope tokens and no private passwords.\n5. Pair the phone directly with this machine, so the build stays isolated.\n6. Take a snapshot of the clean state and return to it after risky work.\nPrepare the exact commands for your system with an AI chat.'),
        GuideItem('What to watch out for in a sandbox?', '• A folder mounted from your main computer is a hole in the isolation: the agent can change scripts you later run outside.\n• Better disable clipboard sharing and drag and drop between systems.\n• Limit the machine\'s network traffic; it should not see your home network.\n• In Tailscale give the machine its own tag and narrow rules.\n• Update the system in the machine like your main one.', important: true, advanced: true),
      ]),
      GuideSection('phone', 'The test phone', [
        GuideItem('Why does the phone ask before installing?', 'Android requires consent to install from outside the store, and some vendors (e.g. HyperOS) ask on every update. This is protection, not a bug. Do not disable phone protections or Play Protect to get around it.'),
        GuideItem('Debug versions and releases', 'Use a debug version for daily testing: build it only for the phone\'s architecture (e.g. --target-platform android-arm64) to keep it smaller. Do not share or publish it. Test a release version before publishing.'),
      ]),
      GuideSection('publish', 'Publishing apps', [
        GuideItem('Where do I start with publishing?', 'Store rules change often, so first research the topic with an AI chat: store requirements, documents, costs and the law in your target countries. Verify everything in the official documentation; a chat can be out of date.', important: true),
        GuideItem('The signing key', 'Every app needs its own release key, different from the debug key. On Google Play you usually use Play App Signing: Google stores the app key and you keep an upload key. Never add a key to the repository or show it to an agent; keep a copy somewhere safe.', important: true),
        GuideItem('Google Play: requirements', '• Personal account created after 13 Nov 2023: a closed test with at least 12 testers for 14 days before production.\n• A privacy policy and the data safety form.\n• Sensitive permissions need a declaration and justification.\n• The application ID cannot change after publishing.\nCheck the current state in Play Console.'),
        GuideItem('Installing outside the store and developer verification', 'Google is introducing developer verification for apps installed on certified devices, including outside the store: from 30 Sep 2026 in Brazil, Indonesia, Singapore and Thailand, globally from 2027. Check dates and exceptions before release, as they may also affect testing outside the store.', important: true),
        GuideItem('Security before release', '• Remove diagnostic logs and test keys.\n• Check dependencies with a vulnerability scanner.\n• Ask an AI chat for an independent security review, and a specialist for sensitive data.\n• Check what data the app collects and on what legal basis (GDPR).'),
      ]),
      GuideSection('decisions', 'Decisions you need to make', [
        GuideItem('A list to think through', '• Where does the agent run: main account or sandbox?\n• Should an agent signal build by itself? Safe only when the build is isolated.\n• Install automatically or ask on the phone?\n• Test phone: separate or private?\n• Which secrets and accounts may the agent see?\n• Who reviews changes, and when?\n• Where are backups and the signing key?\n• May project data reach the AI model provider?\nDiscuss uncertain points with an AI chat, describing your specific case.', important: true),
      ]),
    ],
  ),
  'de': Guide(
    'Ein allgemeiner Leitfaden: wie du RemoteAppTester sicher nutzt und Apps mit KI-Agenten entwickelst. Werkzeuge und Regeln ändern sich schnell — prüfe vor der Umsetzung die aktuelle Lösung mit einem KI-Chat (z. B. Claude, ChatGPT) und in der offiziellen Dokumentation.',
    'Wichtig',
    'Fortgeschritten',
    [
      GuideSection('start', 'So funktioniert diese App', [
        GuideItem('Was macht RemoteAppTester?', 'Die App baut eine Anwendung aus einem gewählten Ordner auf deinem Computer oder Server und liefert sie auf ein Testtelefon. Das Telefon ist die Fernbedienung: Es startet Builds, installiert und startet Versionen. Nichts läuft über RemoteAppTester-Server, denn es gibt keine.'),
        GuideItem('Wie sieht ein typischer Arbeitstag aus?', '• Ein KI-Agent ändert den Projektordner.\n• Danach sendet er ein Signal (Datei .remoteapptester-signal oder rt sg).\n• RemoteAppTester baut mit freigegebenen Befehlen.\n• Das Telefon fragt nach der Installation und startet die neue Version.\n• Du testest und gibst dem Agenten Rückmeldung.'),
      ]),
      GuideSection('security', 'Sichere Nutzung', [
        GuideItem('Was ist bereits geschützt?', '• Verbindung nur über das private Tailscale-Netz, mit beim Koppeln fixiertem Zertifikat und signierter Anfrage.\n• Build-Befehle in einer verschlüsselten Datenbank.\n• Das Telefon sendet keine Befehle oder Pfade.\n• Der Kopplungscode ist einmalig, das Telefon-Geheimnis wechselt alle 30 Tage.'),
        GuideItem('Tailscale: was unbedingt einstellen?', '• Zugriffsregeln (Grants/ACL): Nur deine Telefone dürfen den RemoteAppTester-Port (Standard 47051) erreichen.\n• Tailnet Lock: Ein neues Gerät kommt erst nach Signatur durch deine vertrauenswürdigen Geräte hinzu, selbst der Tailscale-Koordinationsserver kann keines allein hinzufügen.\n• Lass den Ablauf der Geräteschlüssel aktiv (Standard 180 Tage); deaktiviere ihn nur bewusst für einen Server.\n• Aktiviere die Zwei-Faktor-Anmeldung für dein Tailscale-Konto.\nGenaue Schritte: Tailscale-Dokumentation und KI-Chat.', important: true),
        GuideItem('Der Kopplungscode', 'Der QR-Code gewährt Zugriff auf den Computer. Er ist einmalig und 1 Stunde gültig, behandle ihn bis zur Nutzung aber wie ein Passwort. Nicht fotografieren und nicht per Messenger senden. Ein verlorenes Telefon sofort im Reiter Telefone widerrufen; die anderen funktionieren weiter.'),
        GuideItem('Sind Logs sicher?', 'Bevor Logs das Telefon erreichen, werden typische Passwörter, Tokens und der Benutzername gefiltert. Das ist ein Musterfilter und erkennt nicht alles. Gib in Build-Skripten keine Geheimnisse aus.'),
      ]),
      GuideSection('risks', 'Die wichtigsten Risiken', [
        GuideItem('KI-Agent auf meinem Windows-Konto', 'Ein direkt auf deinem Konto gestarteter Agent erreicht alles, was du erreichst: Dateien, Browser-Passwörter, SSH-Schlüssel und auch RemoteAppTester-Daten. DPAPI schützt nicht vor einem Programm, das als du läuft. Sicherer: eine Sandbox (Abschnitt unten).', important: true),
        GuideItem('Ein Build führt Code aus dem Projekt aus', 'Freigegebene Befehle sind nicht alles: Gradle und andere Werkzeuge führen Skripte aus dem Repository aus. Ist der Agent in einer Sandbox, der Build aber auf dem Hauptcomputer, kann er so Code außerhalb der Sandbox starten. Regel: Baue dort, wo der Agent arbeitet.', important: true),
        GuideItem('Ungeprüfte App auf dem Telefon', 'Die getestete App enthält Code, den du vielleicht nicht gelesen hast, und erhält normale Berechtigungen. Nutze am besten ein separates Testtelefon ohne private Daten oder ein Arbeitsprofil. Deshalb ist „Auf dem Telefon fragen“ der Standard.', important: true),
        GuideItem('Prompt Injection', 'Ein Agent liest Webseiten, Issues und Dateien. Darin versteckte Anweisungen können ihn zu Datendiebstahl oder Schadcode verleiten. Beschränke Netz- und Geheimniszugriff und prüfe Änderungen vor der Ausführung.'),
        GuideItem('Gefälschte Pakete und Abhängigkeiten', 'Ein Agent kann eine Bibliothek mit ähnlichem Namen hinzufügen oder eine, die nicht existierte und übernommen wurde. Prüfe neue Abhängigkeiten, pflege die Lock-Datei und nutze einen Schwachstellenscanner.', advanced: true),
      ]),
      GuideSection('agents', 'KI-Agenten: Einrichtung und Arbeit', [
        GuideItem('Wie installiere ich einen Agenten?', '• Nur von der offiziellen Herstellerseite laden (z. B. Claude Code, Codex, VS-Code-Erweiterungen).\n• Am besten in einer Sandbox installieren, nicht im Hauptkonto.\n• Mit einem Konto mit Zwei-Faktor-Anmeldung anmelden.\n• Nur vertrauenswürdige Plugins und MCP-Server hinzufügen, sie haben die Rechte des Agenten.\nAktuelles Vorgehen mit einem KI-Chat prüfen.'),
        GuideItem('Welche Rechte soll ein Agent bekommen?', 'So wenige wie nötig: nur der Projektordner, von dir bestätigte Befehle und kein Modus „alle Rückfragen überspringen“ im Hauptkonto. Vollautomatik nur in der Sandbox.'),
        GuideItem('Geheimnisse und Agenten', 'Speichere Passwörter, API-Schlüssel und den Signaturschlüssel nicht im Repository oder in vom Agenten gelesenen Dateien. Gib dem Agenten eigene Tokens mit engem Umfang und kurzer Laufzeit. Gespräche können beim Modellanbieter landen, prüfe dessen Datenschutzregeln.', important: true),
        GuideItem('Wie arbeite ich mit einem Agenten am Projekt?', '• Git vom ersten Tag: ein Branch pro Aufgabe, kleine Commits.\n• Gib jeweils eine kleine Aufgabe mit Beschreibung, woran man Erfolg erkennt.\n• Prüfe Änderungen, besonders Build-Skripte und Abhängigkeiten.\n• Fordere Tests an und führe sie vor der Installation aus.\n• Lies Befehlsvorschläge im Reiter Befehle vor der Freigabe.\n• Halte Backups außerhalb der Agenten-Maschine.'),
        GuideItem('Der Agent baut die App selbst — wie kommt sie aufs Telefon?', 'Im Projektordner führt der Agent aus: rt push <datei.apk> -m "was geändert wurde" --wait --json\n• Ohne sudo und ohne Zugriff auf RemoteAppTester: der Befehl hinterlässt ein Signal im Projektordner.\n• Angenommen wird nur eine signierte .apk-Datei aus dem Projektordner (eine Datei von anderswo wird dorthin kopiert).\n• Die Installation auf dem Telefon folgt den Projektoptionen (z. B. „fragen“).\n• Ergebnis: Exit-Code (0 = gesendet) und die Datei .remoteapptester-status.json, auch: rt st.\nAbschalten mit der Projektoption „KI-Agent darf eigenes Installationspaket senden“ (rt o --agent-push off).'),
        GuideItem('Kann ich dem vertrauen, was der Agent schrieb?', 'Behandle ihn wie Code eines neuen Kollegen: oft sehr gut, manchmal falsch oder unsicher. Du bist für die App verantwortlich. Anmeldung, Zahlungen und Nutzerdaten brauchen besonders genaue Prüfung.'),
      ]),
      GuideSection('sandbox', 'Sandbox: isoliert arbeiten', [
        GuideItem('Wozu eine Sandbox?', 'Agent, Werkzeuge und Build laufen dann in einem getrennten System. Ein Fehler oder Angriff betrifft nur diese Umgebung, nicht deine Dateien, Passwörter und Konten. Sie lässt sich sauber wiederherstellen.', important: true),
        GuideItem('Welche Lösung soll ich wählen?', '• Virtuelle Maschine (Hyper-V, VirtualBox, VMware): gute Isolation und Snapshots; beste Wahl für regelmäßige Arbeit.\n• Separater Computer oder VPS: stärkste Isolation; RemoteAppTester gibt es für Linux.\n• Windows Sandbox (Pro/Enterprise): schnell, aber beim Schließen gelöscht; für kurze Versuche.\n• Dev Container/Docker: bequem, schwächere Isolation, besonders mit eingebundenen Ordnern.\n• WSL2: sieht standardmäßig Windows-Laufwerke, also allein keine Barriere.\n• Separates Windows-Konto: einfach, aber schwächste Isolation.'),
        GuideItem('Wie richte ich das Schritt für Schritt ein?', '1. Erstelle eine virtuelle Maschine mit sauberem System und eigenem Konto.\n2. Installiere dort Agent, Build-Werkzeuge, RemoteAppTester und Tailscale.\n3. Klone das Repository in die Maschine; binde keine Ordner vom Hauptcomputer ein.\n4. Nutze eigene Tokens mit engem Umfang, keine privaten Passwörter.\n5. Kopple das Telefon direkt mit dieser Maschine, damit der Build isoliert bleibt.\n6. Erstelle einen Snapshot des sauberen Zustands und kehre nach riskanter Arbeit dorthin zurück.\nGenaue Befehle für dein System mit einem KI-Chat vorbereiten.'),
        GuideItem('Worauf in der Sandbox achten?', '• Ein eingebundener Ordner vom Hauptcomputer ist ein Loch in der Isolation: Der Agent kann Skripte ändern, die du außerhalb ausführst.\n• Zwischenablage und Drag & Drop zwischen Systemen besser deaktivieren.\n• Begrenze den Netzverkehr der Maschine; sie soll dein Heimnetz nicht sehen.\n• Gib der Maschine in Tailscale ein eigenes Tag und enge Regeln.\n• Aktualisiere das System in der Maschine wie dein Hauptsystem.', important: true, advanced: true),
      ]),
      GuideSection('phone', 'Das Testtelefon', [
        GuideItem('Warum fragt das Telefon vor der Installation?', 'Android verlangt eine Zustimmung für Installationen außerhalb des Stores, manche Hersteller (z. B. HyperOS) fragen bei jedem Update. Das ist Schutz, kein Fehler. Deaktiviere dafür nicht den Telefonschutz oder Play Protect.'),
        GuideItem('Debug-Versionen und Veröffentlichungen', 'Für tägliche Tests dient die Debug-Version: Baue sie nur für die Telefonarchitektur (z. B. --target-platform android-arm64), dann ist sie kleiner. Nicht weitergeben oder veröffentlichen. Vor der Veröffentlichung die Release-Version testen.'),
      ]),
      GuideSection('publish', 'Apps veröffentlichen', [
        GuideItem('Wo beginne ich mit der Veröffentlichung?', 'Store-Regeln ändern sich oft, recherchiere daher zuerst mit einem KI-Chat: Store-Anforderungen, Dokumente, Kosten, Recht in den Zielländern. Prüfe alles in der offiziellen Dokumentation; ein Chat kann veraltet sein.', important: true),
        GuideItem('Der Signaturschlüssel', 'Jede App braucht einen eigenen Release-Schlüssel, anders als der Debug-Schlüssel. Bei Google Play nutzt man meist Play App Signing: Google verwahrt den App-Schlüssel, du behältst einen Upload-Schlüssel. Schlüssel nie ins Repository legen oder dem Agenten zeigen; eine Kopie sicher aufbewahren.', important: true),
        GuideItem('Google Play: Anforderungen', '• Privatkonto, erstellt nach dem 13.11.2023: vor der Produktion ein geschlossener Test mit mindestens 12 Testern über 14 Tage.\n• Datenschutzerklärung und Formular zur Datensicherheit.\n• Sensible Berechtigungen brauchen Erklärung und Begründung.\n• Die Anwendungs-ID ist nach der Veröffentlichung unveränderlich.\nAktuellen Stand in der Play Console prüfen.'),
        GuideItem('Installation außerhalb des Stores und Entwicklerprüfung', 'Google führt eine Entwicklerprüfung für Apps auf zertifizierten Geräten ein, auch außerhalb des Stores: ab 30.09.2026 in Brasilien, Indonesien, Singapur und Thailand, weltweit ab 2027. Prüfe Termine und Ausnahmen vor der Veröffentlichung, sie können auch Tests außerhalb des Stores betreffen.', important: true),
        GuideItem('Sicherheit vor der Veröffentlichung', '• Entferne Diagnose-Logs und Testschlüssel.\n• Prüfe Abhängigkeiten mit einem Schwachstellenscanner.\n• Lass einen KI-Chat die Sicherheit unabhängig prüfen, bei sensiblen Daten auch einen Fachmann.\n• Prüfe, welche Daten die App erhebt und auf welcher Grundlage (DSGVO).'),
      ]),
      GuideSection('decisions', 'Entscheidungen, die du treffen musst', [
        GuideItem('Eine Liste zum Durchdenken', '• Wo läuft der Agent: Hauptkonto oder Sandbox?\n• Soll ein Agentensignal selbst bauen? Sicher nur, wenn der Build isoliert ist.\n• Automatisch installieren oder auf dem Telefon fragen?\n• Testtelefon: separat oder privat?\n• Welche Geheimnisse und Konten darf der Agent sehen?\n• Wer prüft Änderungen und wann?\n• Wo liegen Backups und Signaturschlüssel?\n• Dürfen Projektdaten zum KI-Modellanbieter gelangen?\nBesprich Unsicheres mit einem KI-Chat anhand deines konkreten Falls.', important: true),
      ]),
    ],
  ),
  'cs': Guide(
    'Obecný průvodce: jak bezpečně používat RemoteAppTester a vyvíjet aplikace s AI agenty. Nástroje a pravidla se rychle mění — než něco nasadíte, ověřte aktuální řešení s AI chatem (např. Claude, ChatGPT) a v oficiální dokumentaci.',
    'Důležité',
    'Pokročilé',
    [
      GuideSection('start', 'Jak tato aplikace funguje', [
        GuideItem('Co RemoteAppTester dělá?', 'Sestaví aplikaci z vybrané složky na vašem počítači nebo serveru a doručí ji na testovací telefon. Telefon je dálkové ovládání: spouští buildy, instaluje a spouští verze. Nic neprochází přes servery RemoteAppTesteru, protože žádné nejsou.'),
        GuideItem('Jak vypadá běžný pracovní den?', '• AI agent změní složku projektu.\n• Po práci pošle signál (soubor .remoteapptester-signal nebo rt sg).\n• RemoteAppTester sestaví schválenými příkazy.\n• Telefon se zeptá na instalaci a spustí novou verzi.\n• Otestujete a vrátíte se k agentovi s poznámkami.'),
      ]),
      GuideSection('security', 'Bezpečné používání', [
        GuideItem('Co je už zabezpečeno?', '• Spojení jen přes soukromou síť Tailscale, s certifikátem připnutým při párování a podpisem každého požadavku.\n• Příkazy pro build v šifrované databázi.\n• Telefon neposílá příkazy ani cesty.\n• Párovací kód je jednorázový a tajemství telefonu se mění každých 30 dní.'),
        GuideItem('Tailscale: co je nutné nastavit?', '• Pravidla přístupu (grants/ACL): k portu RemoteAppTesteru (výchozí 47051) jen vaše telefony.\n• Tailnet Lock: nové zařízení se připojí až po podpisu vašimi důvěryhodnými zařízeními, takže ani koordinační server Tailscale ho nepřidá sám.\n• Vypršení klíčů zařízení (výchozí 180 dní) nechte zapnuté; vypínejte jen vědomě pro server.\n• Zapněte dvoufázové přihlášení k účtu Tailscale.\nPřesné kroky ověřte v dokumentaci Tailscale a s AI chatem.', important: true),
        GuideItem('Párovací kód', 'QR kód dává přístup k počítači. Je jednorázový a platí 1 hodinu, ale do použití s ním zacházejte jako s heslem. Nefoťte ho a neposílejte přes komunikátor. Ztracený telefon hned odvolejte na kartě Telefony; ostatní fungují dál.'),
        GuideItem('Jsou logy bezpečné?', 'Před odesláním na telefon se z logů filtrují typická hesla, tokeny a uživatelské jméno. Je to filtr vzorů, nezachytí všechno. Nevypisujte tajemství v build skriptech.'),
      ]),
      GuideSection('risks', 'Hlavní rizika', [
        GuideItem('AI agent na mém účtu Windows', 'Agent spuštěný přímo na vašem účtu má přístup ke všemu co vy: souborům, heslům v prohlížeči, klíčům SSH i datům RemoteAppTesteru. Šifrování DPAPI nechrání před programem běžícím pod vaším účtem. Bezpečnější: sandbox (sekce níže).', important: true),
        GuideItem('Build spouští kód z projektu', 'Schválené příkazy nejsou všechno: Gradle a další nástroje spouštějí skripty z repozitáře. Je-li agent v sandboxu, ale build běží na hlavním počítači, může agent takto spustit kód mimo sandbox. Pravidlo: sestavujte tam, kde agent pracuje.', important: true),
        GuideItem('Nezkontrolovaná aplikace v telefonu', 'Testovaná aplikace obsahuje kód, který jste možná nečetli, a dostává běžná oprávnění. Nejlépe použijte samostatný testovací telefon bez soukromých dat nebo pracovní profil. Proto je výchozí režim „Zeptat se na telefonu“.', important: true),
        GuideItem('Prompt injection (vložené příkazy)', 'Agent čte webové stránky, požadavky a soubory. Skryté příkazy ho mohou přimět ke krádeži dat nebo přidání škodlivého kódu. Omezte přístup k síti a tajemstvím a změny před spuštěním kontrolujte.'),
        GuideItem('Falešné balíčky a závislosti', 'Agent může přidat knihovnu s podobným názvem nebo takovou, která neexistovala a byla převzata. Kontrolujte nové závislosti, udržujte zámkový soubor a používejte skener zranitelností.', advanced: true),
      ]),
      GuideSection('agents', 'AI agenti: instalace a práce', [
        GuideItem('Jak nainstalovat agenta?', '• Stahujte jen z oficiálních stránek výrobce (např. Claude Code, Codex, rozšíření VS Code).\n• Nejlépe instalujte do sandboxu, ne na hlavní účet.\n• Přihlaste se účtem s dvoufázovým přihlášením.\n• Přidávejte jen důvěryhodné pluginy a servery MCP, mají oprávnění agenta.\nAktuální postup ověřte s AI chatem.'),
        GuideItem('Jaká oprávnění dát agentovi?', 'Co nejmenší: jen složka projektu, příkazy schválené vámi a žádný režim „přeskočit všechny dotazy“ na hlavním účtu. Plně automatický režim nechte pro sandbox.'),
        GuideItem('Tajemství a agent', 'Neukládejte hesla, klíče API ani podpisový klíč do repozitáře ani do souborů, které agent čte. Dejte agentovi samostatné tokeny s úzkým rozsahem a krátkou platností. Konverzace se mohou dostat k poskytovateli modelu, ověřte jeho pravidla soukromí.', important: true),
        GuideItem('Jak s agentem pracovat na projektu?', '• Git od prvního dne: větev na úkol, malé commity.\n• Dávejte jeden malý úkol s popisem, podle čeho poznat, že funguje.\n• Kontrolujte změny, hlavně build skripty a závislosti.\n• Žádejte testy a spouštějte je před instalací.\n• Návrhy příkazů na kartě Příkazy čtěte před schválením.\n• Zálohy držte mimo stroj agenta.'),
        GuideItem('Agent si aplikaci sestaví sám — jak ji dostat na telefon?', 'Ve složce projektu agent spustí: rt push <soubor.apk> -m "co se změnilo" --wait --json\n• Bez sudo a bez přístupu k RemoteAppTesteru: příkaz nechá signál ve složce projektu.\n• Přijímá se jen podepsaný soubor .apk ze složky projektu (soubor odjinud se tam zkopíruje).\n• Instalace na telefonu se řídí možnostmi projektu (např. „zeptat se“).\n• Výsledek: návratový kód (0 = odesláno) a soubor .remoteapptester-status.json, také: rt st.\nVypnete to možností projektu „AI agent smí poslat vlastní instalačku“ (rt o --agent-push off).'),
        GuideItem('Mohu věřit tomu, co agent napsal?', 'Berte ho jako kód nového kolegy: často skvělý, někdy chybný nebo nebezpečný. Za aplikaci odpovídáte vy. Přihlášení, platby a data uživatelů vyžadují zvlášť pečlivou kontrolu.'),
      ]),
      GuideSection('sandbox', 'Sandbox: práce v izolaci', [
        GuideItem('Proč sandbox?', 'Agent, jeho nástroje a build pak běží v odděleném systému. Chyba nebo útok zasáhne jen toto prostředí, ne vaše soubory, hesla a účty. Lze ho obnovit do čistého stavu.', important: true),
        GuideItem('Které řešení zvolit?', '• Virtuální stroj (Hyper-V, VirtualBox, VMware): dobrá izolace a snímky; nejlepší volba pro stálou práci.\n• Samostatný počítač nebo VPS: nejsilnější izolace; RemoteAppTester má verzi pro Linux.\n• Windows Sandbox (Pro/Enterprise): rychlý, ale po zavření se smaže; pro krátké pokusy.\n• Dev Container/Docker: pohodlný, slabší izolace, hlavně s připojenými složkami.\n• WSL2: ve výchozím stavu vidí disky Windows, sám o sobě není bariérou.\n• Samostatný účet Windows: jednoduché, ale nejslabší izolace.'),
        GuideItem('Jak to nastavit krok za krokem?', '1. Vytvořte virtuální stroj s čistým systémem a samostatným účtem.\n2. Nainstalujte do něj agenta, nástroje pro build, RemoteAppTester a Tailscale.\n3. Naklonujte repozitář do stroje; nepřipojujte složky z hlavního počítače.\n4. Použijte samostatné tokeny s úzkým rozsahem, žádná soukromá hesla.\n5. Spárujte telefon přímo s tímto strojem, build tak zůstane v izolaci.\n6. Vytvořte snímek čistého stavu a po riskantní práci se k němu vraťte.\nPřesné příkazy pro svůj systém připravte s AI chatem.'),
        GuideItem('Na co si dát v sandboxu pozor?', '• Složka připojená z hlavního počítače je díra v izolaci: agent může změnit skripty, které spustíte mimo.\n• Sdílení schránky a přetahování souborů mezi systémy raději vypněte.\n• Omezte síťový provoz stroje; nemá vidět vaši domácí síť.\n• V Tailscale dejte stroji vlastní štítek a úzká pravidla.\n• Systém ve stroji aktualizujte stejně jako hlavní.', important: true, advanced: true),
      ]),
      GuideSection('phone', 'Testovací telefon', [
        GuideItem('Proč se telefon ptá na instalaci?', 'Android vyžaduje souhlas s instalací mimo obchod a někteří výrobci (např. HyperOS) se ptají při každé aktualizaci. Je to ochrana, ne chyba. Nevypínejte kvůli tomu ochranu telefonu ani Play Protect.'),
        GuideItem('Ladicí verze a vydání', 'Pro každodenní testy slouží ladicí verze: sestavujte ji jen pro architekturu telefonu (např. --target-platform android-arm64), bude menší. Nesdílejte ji ani nepublikujte. Před publikací otestujte verzi release.'),
      ]),
      GuideSection('publish', 'Publikace aplikací', [
        GuideItem('Kde začít s publikací?', 'Pravidla obchodů se často mění, proto téma nejdřív prozkoumejte s AI chatem: požadavky obchodu, dokumenty, náklady, právo v cílových zemích. Vše ověřte v oficiální dokumentaci; chat může být zastaralý.', important: true),
        GuideItem('Podpisový klíč', 'Každá aplikace potřebuje vlastní klíč pro vydání, jiný než ladicí. V Google Play se obvykle používá Play App Signing: Google uchovává klíč aplikace a vy máte klíč pro nahrávání. Klíč nikdy nedávejte do repozitáře ani neukazujte agentovi; kopii uložte na bezpečném místě.', important: true),
        GuideItem('Google Play: požadavky', '• Osobní účet založený po 13. 11. 2023: před produkcí uzavřený test s nejméně 12 testery po 14 dní.\n• Zásady ochrany soukromí a formulář bezpečnosti dat.\n• Citlivá oprávnění vyžadují prohlášení a zdůvodnění.\n• ID aplikace po publikaci nezměníte.\nAktuální stav ověřte v Play Console.'),
        GuideItem('Instalace mimo obchod a ověření vývojářů', 'Google zavádí ověření vývojářů pro aplikace instalované na certifikovaná zařízení, i mimo obchod: od 30. 9. 2026 v Brazílii, Indonésii, Singapuru a Thajsku, celosvětově od roku 2027. Termíny a výjimky ověřte před vydáním, mohou ovlivnit i testování mimo obchod.', important: true),
        GuideItem('Bezpečnost před vydáním', '• Odstraňte diagnostické logy a testovací klíče.\n• Zkontrolujte závislosti skenerem zranitelností.\n• Požádejte AI chat o nezávislou kontrolu bezpečnosti, u citlivých dat i odborníka.\n• Ověřte, jaká data aplikace sbírá a na jakém základě (GDPR).'),
      ]),
      GuideSection('decisions', 'Rozhodnutí, která musíte udělat', [
        GuideItem('Seznam k promyšlení', '• Kde agent běží: na hlavním účtu nebo v sandboxu?\n• Má signál agenta sám sestavovat? Bezpečné jen při izolovaném buildu.\n• Instalovat automaticky, nebo se ptát na telefonu?\n• Testovací telefon: samostatný, nebo soukromý?\n• Která tajemství a účty smí agent vidět?\n• Kdo a kdy kontroluje změny?\n• Kde jsou zálohy a podpisový klíč?\n• Smí se data projektu dostat k poskytovateli AI modelu?\nNejisté body proberte s AI chatem na svém konkrétním případu.', important: true),
      ]),
    ],
  ),
};
