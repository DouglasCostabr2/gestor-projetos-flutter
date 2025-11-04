import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:world_countries/world_countries.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';

/// Widget reutilizável para seleção de País, Estado e Cidade
/// Usa world_countries para países (com tradução PT-BR) e country_state_city para estados/cidades
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
  List<csc.State> _states = [];
  List<csc.City> _cities = [];

  csc.Country? _selectedCountry;
  csc.State? _selectedState;
  csc.City? _selectedCity;

  bool _loadingStates = false;
  bool _loadingCities = false;
  bool _loadingCountries = false;

  // Cache ESTÁTICO GLOBAL da lista de países traduzidos (compartilhado entre todas as instâncias)
  static List<DropdownItem<String>>? _globalCachedCountryItems;

  // Lista local de países (será preenchida após carregamento assíncrono)
  List<DropdownItem<String>> _countryItems = [];

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
    _selectedState = widget.initialState;
    _selectedCity = widget.initialCity;

    // Carregar lista de países de forma assíncrona
    _loadCountries();

    // Carregar estados e cidades se país/estado inicial existir
    if (_selectedCountry != null) {
      _loadStates(_selectedCountry!.isoCode);

      if (_selectedState != null) {
        _loadCities(_selectedCountry!.isoCode, _selectedState!.isoCode);
      }
    }
  }

  Future<void> _loadCountries() async {
    // Se já tem cache global, usar imediatamente
    if (_globalCachedCountryItems != null) {
      setState(() {
        _countryItems = _globalCachedCountryItems!;
        _loadingCountries = false;
      });
      return;
    }

    // Caso contrário, carregar de forma assíncrona
    setState(() => _loadingCountries = true);

    try {
      // Obter todos os países do world_countries
      final allCountries = WorldCountry.list;

      // Obter locale tipado do contexto (fornecido pelo TypedLocaleDelegate)
      final typedLocale = context.maybeLocale;

      // Converter para DropdownItem com nomes traduzidos
      final countryItems = allCountries.map((country) {
        final translatedName = typedLocale != null
            ? (country.maybeCommonNameFor(typedLocale) ?? country.name.common)
            : country.name.common;

        return DropdownItem<String>(
          value: country.codeShort,
          label: translatedName,
        );
      }).toList();

      // Ordenar por nome traduzido
      countryItems.sort((a, b) => a.label.compareTo(b.label));

      // Cachear globalmente e localmente
      _globalCachedCountryItems = countryItems;

      setState(() {
        _countryItems = countryItems;
        _loadingCountries = false;
      });
    } catch (e) {
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
      setState(() => _loadingCities = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    // Mostrar loading enquanto carrega países
    if (_loadingCountries) {
      return const Column(
        children: [
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando países...'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // País (usando world_countries com tradução)
        GenericDropdownField<String>(
          value: _selectedCountry?.isoCode,
          items: _countryItems,
          onChanged: (isoCode) async {
            // Encontrar o país correspondente no csc para manter compatibilidade
            final cscCountries = await csc.getAllCountries();
            final country = isoCode != null
                ? cscCountries.firstWhere(
                    (c) => c.isoCode == isoCode,
                    orElse: () => csc.Country(
                      name: isoCode,
                      isoCode: isoCode,
                      phoneCode: '',
                      flag: '',
                      currency: '',
                      latitude: '',
                      longitude: '',
                    ),
                  )
                : null;

            setState(() {
              _selectedCountry = country;
              _selectedState = null;
              _selectedCity = null;
              _states = [];
              _cities = [];
            });
            widget.onCountryChanged(country);
            widget.onStateChanged(null);
            widget.onCityChanged(null);

            if (country != null) {
              await _loadStates(country.isoCode);
            }
          },
          labelText: 'País',
          hintText: 'Selecione um país',
        ),
        const SizedBox(height: 16),

        // Estado
        if (_loadingStates)
          const LinearProgressIndicator()
        else
          GenericDropdownField<String?>(
            value: _selectedState?.isoCode,
            items: _states.map((state) {
              return DropdownItem<String?>(
                value: state.isoCode,
                label: state.name,
              );
            }).toList(),
            onChanged: (isoCode) async {
              final state = isoCode != null
                  ? _states.firstWhere((s) => s.isoCode == isoCode)
                  : null;

              setState(() {
                _selectedState = state;
                _selectedCity = null;
                _cities = [];
              });
              widget.onStateChanged(state);
              widget.onCityChanged(null);

              if (state != null && _selectedCountry != null) {
                await _loadCities(_selectedCountry!.isoCode, state.isoCode);
              }
            },
            labelText: 'Estado',
            hintText: _selectedCountry == null
                ? 'Selecione um país primeiro'
                : 'Selecione um estado',
            enabled: !_loadingStates && _selectedCountry != null,
          ),
        const SizedBox(height: 16),

        // Cidade
        if (_loadingCities)
          const LinearProgressIndicator()
        else
          GenericDropdownField<String?>(
            value: _selectedCity?.name,
            items: _cities.map((city) {
              return DropdownItem<String?>(
                value: city.name,
                label: city.name,
              );
            }).toList(),
            onChanged: (cityName) {
              final city = cityName != null
                  ? _cities.firstWhere((c) => c.name == cityName)
                  : null;

              setState(() => _selectedCity = city);
              widget.onCityChanged(city);
            },
            labelText: 'Cidade',
            hintText: _selectedState == null
                ? 'Selecione um estado primeiro'
                : 'Selecione uma cidade',
            enabled: !_loadingCities && _selectedState != null,
          ),
      ],
    );
  }
}

