import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/di/injection.dart';
import '../bloc/auth_bloc.dart';
import '../../../../core/widgets/tv_focusable.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  // Navigation focus nodes (for D-pad movement between fields)
  final _serverNav = FocusNode(debugLabel: 'server-nav');
  final _userNav = FocusNode(debugLabel: 'user-nav');
  final _passNav = FocusNode(debugLabel: 'pass-nav');
  final _connectNav = FocusNode(debugLabel: 'connect-nav');

  // Text editing focus nodes (for when keyboard is open)
  final _serverText = FocusNode(debugLabel: 'server-text');
  final _userText = FocusNode(debugLabel: 'user-text');
  final _passText = FocusNode(debugLabel: 'pass-text');

  bool _obscurePassword = true;
  int _editingField = -1; // -1 = none, 0 = username, 1 = password, 2 = server url

  @override
  void initState() {
    super.initState();
    _serverNav.addListener(_onFocusChange);
    _serverText.addListener(_onFocusChange);
    _userNav.addListener(_onFocusChange);
    _userText.addListener(_onFocusChange);
    _passNav.addListener(_onFocusChange);
    _passText.addListener(_onFocusChange);
    _connectNav.addListener(_onFocusChange);
    context.read<AuthBloc>().add(const CheckStoredCredentials());
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passController.dispose();
    _serverNav.dispose();
    _userNav.dispose();
    _passNav.dispose();
    _connectNav.dispose();
    _serverText.dispose();
    _userText.dispose();
    _passText.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(LoginRequested(
            baseUrl: _serverController.text.trim(),
            username: _userController.text.trim(),
            password: _passController.text.trim(),
          ));
    }
  }

  void _startEditing(int index, FocusNode textNode) {
    setState(() => _editingField = index);
    textNode.requestFocus();
  }

  void _stopEditing(FocusNode navNode) {
    setState(() => _editingField = -1);
    navNode.requestFocus();
  }

  Widget _buildField({
    required int index,
    required String label,
    required TextEditingController controller,
    required FocusNode navNode,
    required FocusNode textNode,
    required IconData icon,
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isEditing = _editingField == index;
    final hasFocus = navNode.hasFocus || textNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Focus(
        focusNode: navNode,
        autofocus: index == 0,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              if (!isEditing) {
                _startEditing(index, textNode);
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: hasFocus ? 2.5 : 1,
            ),
            color: hasFocus
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: textNode,
            readOnly: !isEditing,
            obscureText: obscure && _obscurePassword,
            keyboardType: TextInputType.text,
            // Touch support (phones): tapping the field starts editing,
            // exactly like pressing Select on the remote.
            onTap: () {
              if (!isEditing) {
                _startEditing(index, textNode);
              }
            },
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon),
              suffixIcon: obscure
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onEditingComplete: () => _stopEditing(navNode),
            onFieldSubmitted: (_) => _stopEditing(navNode),
            validator: validator,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthAuthenticated || curr is AuthCheckingStored,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthCheckingStored) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Restoring session…'),
                    ],
                  ),
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 48),

                          // Header
                          Icon(Icons.live_tv,
                              size: 64, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Xtreme IPTV',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your Xtream Codes credentials',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 32),

                          // Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // 1. Username (top)
                                _buildField(
                                  index: 0,
                                  label: 'Username',
                                  controller: _userController,
                                  navNode: _userNav,
                                  textNode: _userText,
                                  icon: Icons.person,
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Username is required'
                                      : null,
                                ),

                                // 2. Password
                                _buildField(
                                  index: 1,
                                  label: 'Password',
                                  controller: _passController,
                                  navNode: _passNav,
                                  textNode: _passText,
                                  icon: Icons.lock,
                                  obscure: true,
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Password is required'
                                      : null,
                                ),

                                // 3. Server URL (bottom)
                                _buildField(
                                  index: 2,
                                  label: 'Server URL',
                                  hint: 'http://1.2.3.4:8080',
                                  controller: _serverController,
                                  navNode: _serverNav,
                                  textNode: _serverText,
                                  icon: Icons.dns,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Server URL is required';
                                    }
                                    if (!v.startsWith('http://') &&
                                        !v.startsWith('https://')) {
                                      return 'Must start with http:// or https://';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 8),

                                // Error message
                                if (state is AuthError) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.error
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.error_outline,
                                          color: theme.colorScheme.error,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          state.message,
                                          style: TextStyle(
                                              color: theme.colorScheme.error,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // 4. Connect button (very bottom)
                                TvFocusable(
                                  autofocus: false,
                                  borderRadius: BorderRadius.circular(12),
                                  onTap:
                                      state is AuthLoading ? null : _submit,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: state is AuthLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Connect',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
