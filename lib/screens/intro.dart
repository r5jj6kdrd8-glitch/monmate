import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mongo_mate/screens/home.dart';
import 'package:mongo_mate/utilities/AdRepository.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({Key? key}) : super(key: key);

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _continued = false;
  bool _showPrivacyPage = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() {
      _continued = true;
      _showPrivacyPage = true;
    });
  }

  void _completeIntro() async {
    AdRepository.showConsentUMP();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen', true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _requestATT() async {
    if (await AppTrackingTransparency.trackingAuthorizationStatus ==
        TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    _completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _showPrivacyPage
          ? AppBackground(child: SafeArea(child: _buildPrivacyPage()))
          : _continued
              ? AppBackground(child: SafeArea(child: _buildWelcomeAnimation()))
              : AppBackground(child: SafeArea(child: _buildOnboarding())),
    );
  }

  Widget _buildOnboarding() {
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          'MonMate',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          Platform.isIOS ? 'MongoDB companion for iPhone' : 'MongoDB companion for Android',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              _OnboardingCard(
                icon: CupertinoIcons.cube_box_fill,
                title: 'Compass-like control',
                description: Platform.isIOS
                    ? 'Manage MongoDB collections and documents in a native iOS-first interface.'
                    : 'Manage MongoDB collections and documents in a native Android interface.',
              ),
              const _OnboardingCard(
                icon: CupertinoIcons.link_circle_fill,
                title: 'Fast connection switching',
                description:
                    'Jump across deployments, edit records quickly, and move through your data with less friction.',
              ),
              const _OnboardingCard(
                icon: CupertinoIcons.search_circle_fill,
                title: 'Filter and sort instantly',
                description:
                    'Use Mongo-style queries and sort definitions to narrow down exactly what matters.',
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final selected = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.all(4),
              width: selected ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(CupertinoIcons.arrow_right),
              label: const Text('Continue'),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildWelcomeAnimation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 76,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Ready to go',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s set up your privacy preferences.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.lock_shield_fill,
                  size: 70, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Privacy Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                'To keep MonMate free, we request tracking permission for personalized ads. You can still continue if declined.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requestATT,
                  child: const Text('Continue'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 66, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
