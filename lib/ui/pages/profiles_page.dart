import 'package:flutter/material.dart';

import '../../domain/user_profile.dart';
import '../../state/app_controller.dart';

void openProfileSettings(BuildContext context, AppController app) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ProfileEditor(controller: app)),
  );
}

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _create(BuildContext context) async {
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un profil'),
        content: TextField(
          onChanged: (value) => name = value,
          autofocus: true,
          maxLength: 32,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Prénom ou pseudo'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final id = controller.createProfile(result);
    if (id.isNotEmpty) controller.selectProfile(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              Text(
                'Qui regarde NOVA ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Vos favoris, vos reprises et vos envies, dans votre profil.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final profile in controller.profiles)
                    SizedBox(
                      width: 175,
                      child: OutlinedButton(
                        autofocus: profile.id == controller.activeProfileId,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(22),
                        ),
                        onPressed: () => controller.selectProfile(profile.id),
                        child: Column(
                          children: [
                            const Icon(Icons.account_circle, size: 64),
                            const SizedBox(height: 12),
                            Text(
                              profile.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (controller.profiles.length < 20)
                    SizedBox(
                      width: 175,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(22),
                        ),
                        onPressed: () => _create(context),
                        child: const Column(
                          children: [
                            Icon(Icons.person_add_alt_1, size: 64),
                            SizedBox(height: 12),
                            Text('Créer un profil'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.controller,
    this.onboarding = false,
  });
  final AppController controller;
  final bool onboarding;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final _name = TextEditingController(
    text: widget.controller.activeProfile.name,
  );
  late final _genres = Set<String>.of(widget.controller.activeProfile.genres);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    widget.controller.updateProfile(_name.text, _genres);
    if (!widget.onboarding) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.onboarding ? 'Vos envies de cinéma' : 'Mon profil et mes genres',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _name,
                maxLength: 32,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nom du profil'),
              ),
              const SizedBox(height: 20),
              Text(
                'Quels genres aimez-vous ?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Choisissez plusieurs genres ou continuez sans préférence. Vous pourrez les modifier dans les paramètres. Les suggestions viennent de vos sources.',
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final genre in preferredGenres.keys)
                    FilterChip(
                      label: Text(genre),
                      selected: _genres.contains(genre),
                      onSelected: (selected) => setState(() {
                        selected ? _genres.add(genre) : _genres.remove(genre);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.onboarding ? 'Entrer dans NOVA' : 'Enregistrer',
                ),
              ),
              if (widget.onboarding)
                TextButton(
                  onPressed: widget.controller.showProfilePicker,
                  child: const Text('Changer de profil'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text('Profil : ${controller.activeProfile.name}'),
        subtitle: Text(
          controller.activeProfile.genres.isEmpty
              ? 'Modifier le profil et les genres préférés'
              : controller.activeProfile.genres.join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openProfileSettings(context, controller),
      ),
      ListTile(
        leading: const Icon(Icons.switch_account),
        title: const Text('Changer ou créer un profil'),
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          controller.showProfilePicker();
        },
      ),
    ],
  );
}
