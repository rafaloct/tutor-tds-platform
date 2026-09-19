import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/responsive_body.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o Programa')),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Descrição do programa
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Territórios de Desenvolvimento Social e Inclusão Produtiva',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF093AF4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'O programa TDS visa impulsionar pequenos produtores, microempreendedores e jovens no Tocantins, '
                      'articulando conhecimento técnico, inovação social e desenvolvimento econômico.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Realização',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _LogoCard(
                asset: 'assets/logos/logo_ipex.png',
                name: 'IPEX — Instituto de Pesquisa e Extensão',
                url: 'https://ead.ipexdesenvolvimento.cloud',
              ),
              const SizedBox(height: 12),
              _LogoCard(
                asset: 'assets/logos/logo_uft.png',
                name: 'Universidade Federal do Tocantins',
                url: 'https://uft.edu.br',
              ),
              const SizedBox(height: 24),

              const Text(
                'Apoio',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LogoCard(
                      asset: 'assets/logos/logo_fapto.png',
                      name: 'FAPTO',
                      url: 'https://fapto.to.gov.br',
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LogoCard(
                      asset: 'assets/logos/logo_cdr.png',
                      name: 'CDR',
                      url: 'https://ead.ipexdesenvolvimento.cloud',
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'TDS 2026 · Tocantins · Brasil',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://ead.ipexdesenvolvimento.cloud'),
                ),
                child: const Text(
                  'ead.ipexdesenvolvimento.cloud',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF093AF4),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  final String asset;
  final String name;
  final String url;
  final bool compact;

  const _LogoCard({
    required this.asset,
    required this.name,
    required this.url,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Image.asset(asset, height: compact ? 48 : 60, fit: BoxFit.contain),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
