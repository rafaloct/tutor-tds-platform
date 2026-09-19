import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/data_sync_service.dart';
import '../widgets/responsive_body.dart';
import '../features/certificates/data/certificate_service.dart';

class CadUnicoScreen extends StatefulWidget {
  const CadUnicoScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _phoneController.text = prefs.getString('user_phone') ?? '';
      _cpfController.text = prefs.getString('user_cpf') ?? '';
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('user_phone', _phoneController.text);
    await prefs.setString('user_cpf', _cpfController.text);

    await DataSyncService.logEvent('REGISTERED', 'Cadastro Inicial');

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
                  'Nome e CPF permitem emitir certificados verificáveis. O CPF não aparece no PDF nem na validação pública.',
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
