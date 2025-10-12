import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

/// Widget reutilizável para seleção de País, Estado e Cidade
/// Gerencia automaticamente o carregamento e dependências entre os campos
class CountryStateCitySelector extends StatefulWidget {
  final csc.Country? initialCountry;
  final csc.State? initialState;
  final csc.City? initialCity;
  final ValueChanged<csc.Country?> onCountryChanged;
  final ValueChanged<csc.State?> onStateChanged;
  final ValueChanged<csc.City?> onCityChanged;

  const CountryStateCitySelector({
    super.key,
    this.initialCountry,
    this.initialState,
    this.initialCity,
    required this.onCountryChanged,
    required this.onStateChanged,
    required this.onCityChanged,
  });

  @override
  State<CountryStateCitySelector> createState() => _CountryStateCitySelectorState();
}

class _CountryStateCitySelectorState extends State<CountryStateCitySelector> {
  List<csc.Country> _countries = [];
  List<csc.State> _states = [];
  List<csc.City> _cities = [];

  csc.Country? _selectedCountry;
  csc.State? _selectedState;
  csc.City? _selectedCity;

  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;

  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
    _selectedState = widget.initialState;
    _selectedCity = widget.initialCity;

    // Inicializar controllers com valores iniciais
    if (_selectedCountry != null) {
      _countryController.text = _selectedCountry!.name;
    }
    if (_selectedState != null) {
      _stateController.text = _selectedState!.name;
    }
    if (_selectedCity != null) {
      _cityController.text = _selectedCity!.name;
    }

    debugPrint('🔵 CountryStateCitySelector initState:');
    debugPrint('   País inicial: ${_selectedCountry?.name}');
    debugPrint('   Estado inicial: ${_selectedState?.name}');
    debugPrint('   Cidade inicial: ${_selectedCity?.name}');

    _loadCountries();
  }

  @override
  void dispose() {
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final countries = await csc.getAllCountries();
      setState(() {
        _countries = countries;
        _loadingCountries = false;
      });

      // Se tem país inicial, carregar estados
      if (_selectedCountry != null) {
        await _loadStates(_selectedCountry!.isoCode);
        
        // Se tem estado inicial, carregar cidades
        if (_selectedState != null) {
          await _loadCities(_selectedCountry!.isoCode, _selectedState!.isoCode);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar países: $e');
      setState(() => _loadingCountries = false);
    }
  }

  Future<void> _loadStates(String countryCode) async {
    setState(() => _loadingStates = true);
    try {
      final states = await csc.getStatesOfCountry(countryCode);
      setState(() {
        _states = states;
        _loadingStates = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar estados: $e');
      setState(() => _loadingStates = false);
    }
  }

  Future<void> _loadCities(String countryCode, String stateCode) async {
    setState(() => _loadingCities = true);
    try {
      final cities = await csc.getStateCities(countryCode, stateCode);
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar cidades: $e');
      setState(() => _loadingCities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // País
            DropdownMenu<csc.Country>(
              controller: _countryController,
              initialSelection: _selectedCountry,
              label: const Text('País'),
              hintText: _loadingCountries ? 'Carregando...' : 'Digite para buscar...',
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              enabled: !_loadingCountries,
              width: constraints.maxWidth,
              dropdownMenuEntries: _countries.map((country) {
                return DropdownMenuEntry<csc.Country>(
                  value: country,
                  label: country.name,
                );
              }).toList(),
              onSelected: (country) async {
                setState(() {
                  _selectedCountry = country;
                  _selectedState = null;
                  _selectedCity = null;
                  _states = [];
                  _cities = [];
                  _stateController.clear();
                  _cityController.clear();
                });
                widget.onCountryChanged(country);
                widget.onStateChanged(null);
                widget.onCityChanged(null);

                if (country != null) {
                  await _loadStates(country.isoCode);
                }
              },
            ),
        const SizedBox(height: 16),

            // Estado
            DropdownMenu<csc.State>(
              controller: _stateController,
              initialSelection: _selectedState,
              label: const Text('Estado'),
              hintText: _loadingStates
                  ? 'Carregando...'
                  : _selectedCountry == null
                      ? 'Selecione um país primeiro'
                      : 'Digite para buscar...',
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              enabled: !_loadingStates && _selectedCountry != null,
              width: constraints.maxWidth,
              dropdownMenuEntries: _states.map((state) {
                return DropdownMenuEntry<csc.State>(
                  value: state,
                  label: state.name,
                );
              }).toList(),
              onSelected: _selectedCountry == null
                  ? null
                  : (state) async {
                      setState(() {
                        _selectedState = state;
                        _selectedCity = null;
                        _cities = [];
                        _cityController.clear();
                      });
                      widget.onStateChanged(state);
                      widget.onCityChanged(null);

                      if (state != null && _selectedCountry != null) {
                        await _loadCities(_selectedCountry!.isoCode, state.isoCode);
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Cidade
            DropdownMenu<csc.City>(
              controller: _cityController,
              initialSelection: _selectedCity,
              label: const Text('Cidade'),
              hintText: _loadingCities
                  ? 'Carregando...'
                  : _selectedState == null
                      ? 'Selecione um estado primeiro'
                      : 'Digite para buscar...',
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              enabled: !_loadingCities && _selectedState != null,
              width: constraints.maxWidth,
              dropdownMenuEntries: _cities.map((city) {
                return DropdownMenuEntry<csc.City>(
                  value: city,
                  label: city.name,
                );
              }).toList(),
              onSelected: _selectedState == null
                  ? null
                  : (city) {
                      setState(() => _selectedCity = city);
                      widget.onCityChanged(city);
                    },
            ),
          ],
        );
      },
    );
  }
}

