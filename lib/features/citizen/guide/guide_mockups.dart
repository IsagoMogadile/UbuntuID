/// Simplified pictures of the citizen screens for the user guide, drawn as
/// SVG so the same picture shows in the app (flutter_svg) and in the
/// downloadable PDF (pdf's SvgImage). Each picture is a phone showing one
/// screen, with the parts a guide topic talks about ringed in gold and
/// numbered to match its steps.
///
/// Text stays plain ASCII: the PDF's built-in fonts only cover Latin-1.
enum GuideScreen {
  dashboard,
  services,
  notifications,
  moreSheet,
  wallet,
  documents,
  verification,
  consent,
  profile,
  settings,
  accessibility,
  reports,
}

class GuideMockup {
  const GuideMockup(this.screen, {this.highlights = const []});

  final GuideScreen screen;

  /// Parts of the screen to ring, numbered 1, 2, 3... in this order.
  final List<String> highlights;

  static const width = 260.0;
  static const height = 460.0;

  String toSvg() {
    final c = _Canvas();
    c.phone();
    switch (screen) {
      case GuideScreen.dashboard:
        c.shellHeader();
        c.dashboardBody();
        c.bottomNav(0);
      case GuideScreen.services:
        c.shellHeader();
        c.servicesBody();
        c.bottomNav(1);
      case GuideScreen.notifications:
        c.shellHeader();
        c.notificationsBody();
        c.bottomNav(2);
      case GuideScreen.moreSheet:
        c.shellHeader();
        c.dashboardBody();
        c.bottomNav(0);
        c.moreSheet();
      case GuideScreen.wallet:
        c.walletBody();
      case GuideScreen.documents:
        c.pushedHeader('Documents');
        c.documentsBody();
      case GuideScreen.verification:
        c.pushedHeader('Verification Requests');
        c.verificationBody();
      case GuideScreen.consent:
        c.pushedHeader('Verification Consent');
        c.consentBody();
      case GuideScreen.profile:
        c.pushedHeader('Profile');
        c.profileBody();
      case GuideScreen.settings:
        c.shellHeader();
        c.settingsBody();
        c.bottomNav(4);
      case GuideScreen.accessibility:
        c.pushedHeader('Accessibility');
        c.accessibilityBody();
      case GuideScreen.reports:
        c.shellHeader();
        c.reportsBody();
        c.bottomNav(3);
    }
    for (final (i, name) in highlights.indexed) {
      c.highlight(name, i + 1);
    }
    return c.svg();
  }
}

class _Box {
  const _Box(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

class _Canvas {
  final _out = StringBuffer();
  final _targets = <String, _Box>{};

  // Brand colours, as in AppColors.
  static const green = '#00723F';
  static const greenLight = '#E3F3E9';
  static const gold = '#C9962C';
  static const goldLight = '#F7ECD6';
  static const ink = '#1B1F1D';
  static const muted = '#54615B';
  static const bg = '#FAFAF8';
  static const surface = '#FFFFFF';
  static const surfaceMuted = '#F1F3F1';
  static const border = '#DCE1DD';
  static const success = '#1E7B45';
  static const successBg = '#E4F3E9';
  static const warning = '#8A5D0A';
  static const warningBg = '#FBF0DA';
  static const error = '#B3261E';

  // The phone's screen.
  static const sx = 8.0, sy = 8.0, sw = 244.0, sh = 444.0;
  static const navTop = 404.0;

  String svg() =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${GuideMockup.width.toInt()} ${GuideMockup.height.toInt()}" '
      'width="${GuideMockup.width.toInt()}" height="${GuideMockup.height.toInt()}">$_out</svg>';

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void rect(double x, double y, double w, double h,
      {String fill = 'none', String? stroke, double sw = 1, double rx = 0, double? opacity}) {
    _out.write('<rect x="${_n(x)}" y="${_n(y)}" width="${_n(w)}" height="${_n(h)}" rx="${_n(rx)}" fill="$fill"');
    if (stroke != null) _out.write(' stroke="$stroke" stroke-width="${_n(sw)}"');
    if (opacity != null) _out.write(' fill-opacity="$opacity"');
    _out.write('/>');
  }

  void circle(double cx, double cy, double r, {String fill = 'none', String? stroke, double sw = 1}) {
    _out.write('<circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}" fill="$fill"');
    if (stroke != null) _out.write(' stroke="$stroke" stroke-width="${_n(sw)}"');
    _out.write('/>');
  }

  void path(String d, {String stroke = ink, double sw = 1.4, String fill = 'none'}) {
    _out.write('<path d="$d" fill="$fill" stroke="$stroke" stroke-width="${_n(sw)}" '
        'stroke-linecap="round" stroke-linejoin="round"/>');
  }

  void text(double x, double y, String s,
      {double size = 7, String fill = ink, bool bold = false, String anchor = 'start'}) {
    _out.write('<text x="${_n(x)}" y="${_n(y)}" font-family="sans-serif" font-size="${_n(size)}" '
        'font-weight="${bold ? 'bold' : 'normal'}" font-style="normal" fill="$fill" text-anchor="$anchor">${_esc(s)}</text>');
  }

  void target(String name, double x, double y, double w, double h) => _targets[name] = _Box(x, y, w, h);

  /// A small rounded square standing in for an icon.
  void icon(double cx, double cy, {String color = green, double size = 11}) {
    rect(cx - size / 2, cy - size / 2, size, size, fill: greenLight, stroke: color, sw: 1, rx: 3);
  }

  void phone() {
    rect(0, 0, GuideMockup.width, GuideMockup.height, fill: ink, rx: 26);
    rect(sx, sy, sw, sh, fill: bg, rx: 18);
    text(24, 19, '9:41', size: 6, fill: muted, bold: true);
    rect(110, 13, 40, 5, fill: ink, rx: 2.5);
  }

  /// The citizen header: logo and name on the left, Guide and Profile on the right.
  void shellHeader() {
    rect(sx, 24, sw, 34, fill: surface);
    path('M${_n(sx)} 58 h${_n(sw)}', stroke: border, sw: 1);
    circle(26, 41, 8, fill: green);
    circle(26, 41, 3, fill: gold);
    text(39, 45, 'UbuntuID', size: 11, bold: true);
    rect(166, 31, 50, 20, fill: greenLight, stroke: green, sw: 1, rx: 10);
    circle(178, 41, 5.5, fill: 'none', stroke: green, sw: 1.2);
    text(178, 43.5, '?', size: 7, fill: green, bold: true, anchor: 'middle');
    text(186, 44, 'Guide', size: 7.5, fill: green, bold: true);
    target('guide', 166, 31, 50, 20);
    circle(234, 41, 9, stroke: ink, sw: 1.3);
    circle(234, 38.5, 3, stroke: ink, sw: 1.2);
    path('M228.5 47 q5.5 -6 11 0', sw: 1.2);
    target('profile', 225, 32, 18, 18);
  }

  /// A full-screen page opened from somewhere else: back arrow and title.
  void pushedHeader(String title, {String fill = surface, String color = ink}) {
    rect(sx, 24, sw, 34, fill: fill);
    if (fill == surface) path('M${_n(sx)} 58 h${_n(sw)}', stroke: border, sw: 1);
    path('M30 41 h-10 M20 41 l5 -5 M20 41 l5 5', stroke: color, sw: 1.5);
    text(40, 45, title, size: 11, bold: true, fill: color);
    target('back', 15, 32, 18, 18);
  }

  static const _navLabels = ['Dashboard', 'Services', 'Notifications', 'Reports', 'More'];

  void bottomNav(int selected) {
    rect(sx, navTop, sw, 40, fill: surfaceMuted);
    final itemW = sw / _navLabels.length;
    for (var i = 0; i < _navLabels.length; i++) {
      final cx = sx + itemW * (i + 0.5);
      if (i == selected) rect(cx - 14, navTop + 5, 28, 15, fill: '#CDE8D7', rx: 7.5);
      rect(cx - 6, navTop + 8, 12, 9, stroke: i == selected ? green : muted, sw: 1.2, rx: 2);
      text(cx, navTop + 31, _navLabels[i], size: 6, fill: i == selected ? green : muted, bold: i == selected, anchor: 'middle');
      target('nav:$i', cx - itemW / 2 + 2, navTop + 2, itemW - 4, 36);
    }
    // Unread notifications badge.
    final bellX = sx + itemW * 2.5 + 7;
    circle(bellX, navTop + 8, 5, fill: error);
    text(bellX, navTop + 10.2, '2', size: 6, fill: surface, bold: true, anchor: 'middle');
    target('nav', sx + 2, navTop + 2, sw - 4, 36);
    rect(100, 446, 60, 3, fill: ink, rx: 1.5);
  }

  void sectionHeader(double y, String title, {String? action}) {
    text(20, y, title, size: 8.5, bold: true);
    if (action != null) text(240, y, action, size: 6.5, fill: green, bold: true, anchor: 'end');
  }

  void listRow(double y, String title, String subtitle,
      {double h = 30, bool chevron = true, String? badge, String badgeFill = successBg, String badgeInk = success}) {
    rect(20, y, 220, h, fill: surface, stroke: border, rx: 7);
    icon(34, y + h / 2);
    text(46, y + h / 2 - 1.5, title, size: 7, bold: true);
    text(46, y + h / 2 + 7, subtitle, size: 5.6, fill: muted);
    if (badge != null) {
      rect(196, y + h / 2 - 6, 38, 12, fill: badgeFill, rx: 6);
      text(215, y + h / 2 + 2, badge, size: 5.5, fill: badgeInk, bold: true, anchor: 'middle');
    } else if (chevron) {
      path('M229 ${_n(y + h / 2 - 4)} l4 4 l-4 4', stroke: muted, sw: 1.2);
    }
  }

  void idCard(double x, double y) {
    rect(x, y, 220, 108, fill: green, rx: 10);
    text(x + 10, y + 15, 'REPUBLIC OF SOUTH AFRICA', size: 5.8, fill: goldLight, bold: true);
    text(x + 10, y + 26, 'Digital Identity', size: 8, fill: surface, bold: true);
    rect(x + 10, y + 34, 34, 42, fill: greenLight, rx: 4);
    circle(x + 27, y + 50, 7, fill: '#9CC9AE');
    path('M${_n(x + 15)} ${_n(y + 74)} q12 -16 24 0', stroke: '#9CC9AE', sw: 5);
    text(x + 52, y + 46, 'THANDI DLAMINI', size: 7.5, fill: surface, bold: true);
    text(x + 52, y + 58, 'ID 900101 5800 08 6', size: 6.3, fill: greenLight);
    text(x + 52, y + 69, 'Status: Active', size: 6.3, fill: greenLight);
    rect(x + 170, y + 32, 40, 40, fill: surface, rx: 3);
    // A QR-like pattern: three finder squares and scattered modules.
    for (final (fx, fy) in [(x + 173, y + 35), (x + 197, y + 35), (x + 173, y + 59)]) {
      rect(fx, fy, 10, 10, fill: ink, rx: 1);
      rect(fx + 2, fy + 2, 6, 6, fill: surface);
      rect(fx + 3.5, fy + 3.5, 3, 3, fill: ink);
    }
    for (var i = 0; i < 18; i++) {
      final mx = x + 186 + (i * 7 % 22);
      final my = y + 48 + (i * 5 % 21);
      rect(mx, my, 3, 3, fill: ink);
    }
    text(x + 10, y + 98, 'Tap to open your Document Wallet.', size: 6, fill: goldLight);
  }

  void dashboardBody() {
    idCard(20, 66);
    target('idCard', 20, 66, 220, 108);

    sectionHeader(190, 'Identity status');
    rect(20, 196, 220, 26, fill: surface, stroke: border, rx: 6);
    circle(32, 209, 5, fill: success);
    path('M29.5 209 l2 2 l3.5 -4', stroke: surface, sw: 1.2);
    text(42, 211.5, 'Your identity is verified with Home Affairs.', size: 6, fill: ink);
    target('status', 20, 196, 220, 26);

    sectionHeader(238, 'Quick actions');
    const labels = ['Documents', 'Who checked', 'Timeline', 'User guide'];
    const keys = ['qa:documents', 'qa:verification', 'qa:timeline', 'qa:guide'];
    for (var i = 0; i < labels.length; i++) {
      final x = 20 + i * 56.7;
      rect(x, 244, 50, 42, fill: surface, stroke: border, rx: 7);
      icon(x + 25, 258);
      text(x + 25, 278, labels[i], size: 5.6, anchor: 'middle');
      target(keys[i], x, 244, 50, 42);
    }
    target('quickActions', 20, 244, 220, 42);

    sectionHeader(302, 'Notifications', action: 'View all (2 new)');
    target('viewAll', 182, 294, 60, 12);
    for (final (i, msg) in ['Your matric results are available', 'Kops Tech verified your identity'].indexed) {
      final y = 308.0 + i * 34;
      rect(20, y, 220, 29, fill: surface, stroke: border, rx: 7);
      icon(34, y + 14.5);
      text(46, y + 13, msg, size: 6.5, bold: true);
      text(46, y + 22, 'In-app', size: 5.5, fill: muted);
      circle(230, y + 14.5, 3.5, fill: gold);
    }
    target('dashNotifications', 20, 308, 220, 63);
  }

  void servicesBody() {
    text(20, 76, 'Government Services', size: 10, bold: true);
    const names = [
      'Home Affairs',
      "Driver's Licence",
      'Tax & SARS',
      'Police Clearance',
      'Basic Education',
      'Higher Education',
      'Employment & UIF',
      'SASSA Grants',
      'Human Settlements',
      'My Employment',
    ];
    for (var i = 0; i < names.length; i++) {
      final x = i.isEven ? 20.0 : 134.0;
      final y = 86.0 + (i ~/ 2) * 62;
      rect(x, y, 106, 54, fill: surface, stroke: border, rx: 7);
      icon(x + 14, y + 14, size: 12);
      text(x + 8, y + 33, names[i], size: 6.6, bold: true);
      rect(x + 8, y + 39, 82, 3, fill: border, rx: 1.5);
      rect(x + 8, y + 45, 60, 3, fill: border, rx: 1.5);
      target('svc:${names[i]}', x, y, 106, 54);
    }
    target('servicesGrid', 20, 86, 220, 302);
  }

  void notificationsBody() {
    text(20, 76, 'Notifications', size: 10, bold: true);
    const messages = [
      'Your matric results are available',
      'Kops Tech verified your identity',
      "Driver's licence renewed",
      'Consent granted to FNB',
      'Welcome to UbuntuID',
    ];
    for (var i = 0; i < messages.length; i++) {
      final y = 86.0 + i * 40;
      rect(20, y, 220, 34, fill: surface, stroke: border, rx: 7);
      icon(34, y + 17);
      text(46, y + 15, messages[i], size: 6.8, bold: i < 2);
      text(46, y + 25, i < 2 ? 'New - tap to read' : 'Read', size: 5.6, fill: muted);
      if (i < 2) circle(230, y + 17, 3.5, fill: gold);
    }
    target('notif:0', 20, 86, 220, 34);
    target('notifList', 20, 86, 220, 194);
  }

  void moreSheet() {
    rect(sx, sy, sw, sh, fill: ink, rx: 18, opacity: 0.45);
    rect(sx, 330, sw, 122, fill: surface, rx: 16);
    rect(110, 337, 40, 4, fill: border, rx: 2);
    for (final (i, label) in ['Settings', 'Log Out'].indexed) {
      final y = 352.0 + i * 36;
      icon(34, y + 12);
      text(50, y + 15, label, size: 8, bold: true);
      target(i == 0 ? 'sheet:settings' : 'sheet:logout', 20, y, 220, 26);
    }
  }

  void walletBody() {
    rect(sx, sy, sw, sh, fill: '#10130F', rx: 18);
    text(24, 19, '9:41', size: 6, fill: '#BFC7C2', bold: true);
    pushedHeader('Document Wallet', fill: '#10130F', color: surface);
    idCard(20, 110);
    target('wallet:card', 20, 110, 220, 108);
    for (var i = 0; i < 4; i++) {
      circle(112 + i * 12.0, 240, i == 0 ? 4 : 3, fill: i == 0 ? surface : '#5E6661');
    }
    target('wallet:dots', 100, 232, 60, 16);
    text(130, 262, '1 of 4 - swipe or tap a dot', size: 6, fill: '#8C948F', anchor: 'middle');
    rect(80, 274, 100, 24, stroke: '#8C948F', sw: 1, rx: 12);
    path('M100 281 v8 M96.5 285.5 l3.5 3.5 l3.5 -3.5', stroke: surface, sw: 1.3);
    text(140, 289, 'Download PDF', size: 7.5, fill: surface, bold: true, anchor: 'middle');
    target('wallet:download', 80, 274, 100, 24);
  }

  void downloadIcon(double cx, double cy, {String color = green}) {
    path('M${_n(cx)} ${_n(cy - 5)} v7 M${_n(cx - 3.5)} ${_n(cy - 1.5)} l3.5 3.5 l3.5 -3.5 M${_n(cx - 5)} ${_n(cy + 5)} h10',
        stroke: color, sw: 1.4);
  }

  void documentsBody() {
    sectionHeader(78, 'Downloadable documents');
    const docs = [
      ('Identity document', 'Front and back - Home Affairs'),
      ("Driver's licence", 'Department of Transport'),
      ('Matric certificate (NSC)', 'Basic Education'),
      ('Tax compliance status', 'SARS'),
    ];
    for (var i = 0; i < docs.length; i++) {
      final y = 86.0 + i * 36;
      listRow(y, docs[i].$1, docs[i].$2, chevron: false);
      downloadIcon(229, y + 15);
      if (i == 0) target('doc:download', 220, y + 6, 18, 18);
    }
    target('doc:list', 20, 86, 220, 138);
    sectionHeader(248, 'Documents on file');
    listRow(256, 'Proof of address.pdf', 'Uploaded 2 Oct 2026', badge: 'Verified');
    target('doc:onFile', 20, 256, 220, 30);
  }

  void verificationBody() {
    const rows = [
      ('Kops Tech', 'Identity, Matric - 12 Oct 2026', 'Completed', successBg, success),
      ('FNB', 'Identity - 9 Oct 2026', 'Pending', warningBg, warning),
      ('City of Tshwane', 'Identity, Licence - 1 Oct 2026', 'Completed', successBg, success),
      ('Bidvest', 'Employment - 20 Sep 2026', 'Rejected', '#FBE9E8', error),
    ];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      listRow(70.0 + i * 38, r.$1, r.$2, h: 32, badge: r.$3, badgeFill: r.$4, badgeInk: r.$5);
    }
    target('ver:0', 20, 70, 220, 32);
    target('ver:badge', 194, 76, 42, 20);
  }

  void consentBody() {
    const rows = [
      ('Kops Tech', 'Can verify: Identity, Matric'),
      ('FNB', 'Can verify: Identity'),
      ('City of Tshwane', 'Can verify: Identity, Licence'),
    ];
    for (var i = 0; i < rows.length; i++) {
      final y = 70.0 + i * 44;
      rect(20, y, 220, 38, fill: surface, stroke: border, rx: 7);
      icon(34, y + 19);
      text(46, y + 16, rows[i].$1, size: 7, bold: true);
      text(46, y + 26, rows[i].$2, size: 5.6, fill: muted);
      rect(196, y + 12, 36, 14, stroke: error, sw: 1, rx: 7);
      text(214, y + 21.5, 'Revoke', size: 5.8, fill: error, bold: true, anchor: 'middle');
      if (i == 0) target('consent:revoke', 196, y + 12, 36, 14);
    }
    target('consent:list', 20, 70, 220, 126);
  }

  void profileBody() {
    rect(20, 68, 220, 46, fill: surface, stroke: border, rx: 8);
    circle(42, 91, 13, fill: greenLight);
    text(42, 95, 'TD', size: 8, fill: green, bold: true, anchor: 'middle');
    text(62, 89, 'Thandi Dlamini', size: 8, bold: true);
    text(62, 99, 'thandi.dlamini@ubuntuid.gov.za', size: 6, fill: muted);
    sectionHeader(132, 'Account');
    listRow(140, 'Personal information', 'Name, ID number, contact details');
    target('profile:personal', 20, 140, 220, 30);
    listRow(176, 'Verification consent', 'Which organisations can verify you');
    target('profile:consent', 20, 176, 220, 30);
    listRow(212, 'Accessibility', 'Text size, theme, read aloud');
    target('profile:accessibility', 20, 212, 220, 30);
  }

  void settingsBody() {
    text(20, 76, 'Settings', size: 10, bold: true);
    sectionHeader(92, 'Preferences');
    const rows = [
      ('Account', 'Email and password'),
      ('Security', 'Sign-in and device security'),
      ('Notifications', 'How UbuntuID contacts you'),
      ('Privacy', 'Consent and data sharing'),
      ('Accessibility', 'Theme, text size, read aloud'),
      ('Feedback', 'Complaints, compliments, suggestions'),
      ('About UbuntuID', 'Version and legal'),
      ('Sign out', 'Leave UbuntuID on this device'),
    ];
    for (var i = 0; i < rows.length; i++) {
      final y = 98.0 + i * 37;
      listRow(y, rows[i].$1, rows[i].$2, h: 31);
      target('set:${rows[i].$1}', 20, y, 220, 31);
    }
  }

  void accessibilityBody() {
    sectionHeader(78, 'Theme');
    rect(20, 84, 220, 22, fill: surface, stroke: border, rx: 11);
    for (final (i, label) in ['System', 'Light', 'Dark'].indexed) {
      final x = 20 + i * 73.3;
      if (i == 0) rect(x, 84, 73.3, 22, fill: '#CDE8D7', rx: 11);
      text(x + 36.7, 98, label, size: 7, bold: i == 0, fill: i == 0 ? green : ink, anchor: 'middle');
    }
    target('a11y:theme', 20, 84, 220, 22);

    sectionHeader(126, 'Text size');
    for (final (i, label) in ['Default', 'Large', 'Larger', 'Largest'].indexed) {
      final x = 20 + i * 55.0;
      rect(x, 132, 50, 20, fill: i == 0 ? '#CDE8D7' : surface, stroke: i == 0 ? green : border, rx: 6);
      text(x + 25, 145, label, size: 6.5 + i * 0.6, bold: i == 0, anchor: 'middle');
    }
    rect(20, 158, 220, 22, fill: surfaceMuted, rx: 6);
    text(28, 172, 'This is how text will look across UbuntuID.', size: 6.2, fill: muted);
    target('a11y:text', 20, 132, 220, 48);

    for (final (i, row) in [('Reduce motion', 'Turn off animations'), ('Read aloud', 'Tap anything once to hear it')].indexed) {
      final y = 194.0 + i * 40;
      rect(20, y, 220, 34, fill: surface, stroke: border, rx: 7);
      text(30, y + 15, row.$1, size: 7.5, bold: true);
      text(30, y + 25, row.$2, size: 5.8, fill: muted);
      final on = i == 1;
      rect(206, y + 10, 26, 14, fill: on ? green : border, rx: 7);
      circle(on ? 225 : 213, y + 17, 5, fill: surface);
      target(i == 0 ? 'a11y:motion' : 'a11y:read', 20, y, 220, 34);
    }
  }

  void reportsBody() {
    text(20, 76, 'Reports', size: 10, bold: true);
    downloadIcon(230, 72);
    target('rep:download', 220, 62, 20, 20);
    rect(20, 86, 80, 18, fill: greenLight, stroke: green, rx: 9);
    text(60, 98, 'Last 30 days', size: 6.5, fill: green, bold: true, anchor: 'middle');
    target('rep:period', 20, 86, 80, 18);
    for (final (i, stat) in [('4', 'Verifications'), ('2', 'Documents'), ('6', 'Notices')].indexed) {
      final x = 20 + i * 74.0;
      rect(x, 112, 68, 44, fill: surface, stroke: border, rx: 7);
      text(x + 10, 134, stat.$1, size: 14, bold: true, fill: green);
      text(x + 10, 148, stat.$2, size: 6, fill: muted);
    }
    sectionHeader(176, 'Verifications over time');
    rect(20, 182, 220, 120, fill: surface, stroke: border, rx: 7);
    const bars = <double>[20, 45, 30, 70, 55, 85, 40];
    for (var i = 0; i < bars.length; i++) {
      final x = 34 + i * 29.0;
      rect(x, 290 - bars[i], 16, bars[i], fill: i == 5 ? gold : green, rx: 2);
    }
    path('M30 290 h200', stroke: border, sw: 1);
  }

  /// A gold ring around [name] with a numbered badge on its top-left corner.
  void highlight(String name, int number) {
    final t = _targets[name];
    if (t == null) return;
    rect(t.x - 3, t.y - 3, t.w + 6, t.h + 6, stroke: gold, sw: 2.5, rx: 7);
    final bx = (t.x - 3).clamp(sx + 9, sx + sw - 9).toDouble();
    final by = (t.y - 3).clamp(sy + 9, sy + sh - 9).toDouble();
    circle(bx, by, 8, fill: gold, stroke: surface, sw: 1.5);
    text(bx, by + 3, '$number', size: 8.5, fill: surface, bold: true, anchor: 'middle');
  }
}
