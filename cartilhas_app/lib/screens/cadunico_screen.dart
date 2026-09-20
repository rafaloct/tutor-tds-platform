import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import '../features/profile/data/profile_data_store.dart';
import '../widgets/responsive_body.dart';
import '../features/certificates/data/certificate_service.dart';
import '../features/analytics/app_telemetry_service.dart';

class CadUnicoScreen extends StatefulWidget {
  const CadUnicoScreen({super.key, this.profileDataStore});

  final ProfileDataStore? profileDataStore;

  @override
  State<CadUnicoScreen> createState() => _CadUnicoScreenState();
}

class _CadUnicoScreenState extends State<CadUnicoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();

  final phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
  late final ProfileDataStore _profileDataStore;

  @override
  void initState() {
    super.initState();
    _profileDataStore = widget.profileDataStore ?? SecureProfileDataStore();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final profile = await _profileDataStore.read();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _cpfController.text = profile.cpf;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    await _profileDataStore.write(
      ProfileData(
        name: _nameController.text,
        phone: _phoneController.text,
        cpf: _cpfController.text,
      ),
    );

    if (!mounted) return;
    await context.read<AppTelemetryService>().trackFeature(
      featureId: 'profile_saved',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados cadastrados com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Cadastro TDS')),
      body: ResponsiveBody(
        maxWidth: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Nome e CPF permitem emitir certificados verificáveis. O CPF fica protegido pelo dispositivo e não aparece no PDF nem na validação pública.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [phoneMask],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpfController,
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [cpfMask],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      CertificateService.isValidCpf(value ?? '')
                      ? null
                      : 'Informe um CPF válido',
                  onFieldSubmitted: (_) => _submitData(),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submitData,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Salvar Cadastro',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
