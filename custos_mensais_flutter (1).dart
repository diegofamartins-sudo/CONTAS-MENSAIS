import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustosApp());
}

class CustosApp extends StatelessWidget {
  const CustosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custos Mensais - Web',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const HomePage(),
    );
  }
}

class Custo {
  String titulo;
  double valor;
  DateTime vencimento;
  String status; // "Pendente", "Pago", "Atrasado"
  String categoria; // Categoria

  Custo({
    required this.titulo,
    required this.valor,
    required this.vencimento,
    this.status = "Pendente",
    this.categoria = "Outros",
  });

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'valor': valor,
      'vencimento': vencimento.toIso8601String(),
      'status': status,
      'categoria': categoria,
    };
  }

  factory Custo.fromMap(Map<String, dynamic> map) {
    return Custo(
      titulo: map['titulo'],
      valor: map['valor'],
      vencimento: DateTime.parse(map['vencimento']),
      status: map['status'],
      categoria: map['categoria'],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Custo> custos = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _carregarCustos();
  }

  Future<void> _carregarCustos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonCustos = prefs.getString('custos');
    if (jsonCustos != null) {
      List<dynamic> lista = jsonDecode(jsonCustos);
      setState(() {
        custos = lista.map((e) => Custo.fromMap(e)).toList();
      });
    }
  }

  Future<void> _salvarCustos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonCustos = jsonEncode(custos.map((e) => e.toMap()).toList());
    await prefs.setString('custos', jsonCustos);
  }

  void _adicionarCusto() {
    showDialog(
      context: context,
      builder: (context) {
        final tituloController = TextEditingController();
        final valorController = TextEditingController();
        DateTime vencimento = DateTime.now();
        String categoriaSelecionada = "Outros";

        return AlertDialog(
          title: const Text("Novo Custo"),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: tituloController,
                    decoration: const InputDecoration(labelText: "Descrição"),
                  ),
                  TextField(
                    controller: valorController,
                    decoration: const InputDecoration(labelText: "Valor"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: categoriaSelecionada,
                    items: ["Alimentação", "Transporte", "Contas", "Lazer", "Outros"]
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        categoriaSelecionada = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (data != null) {
                        vencimento = data;
                      }
                    },
                    child: const Text("Selecionar Data de Vencimento"),
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final novoCusto = Custo(
                  titulo: tituloController.text,
                  valor: double.tryParse(valorController.text) ?? 0,
                  vencimento: vencimento,
                  categoria: categoriaSelecionada,
                );
                setState(() {
                  custos.add(novoCusto);
                });
                _salvarCustos();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Custo "${novoCusto.titulo}" adicionado!')),
                );
              },
              child: const Text("Salvar"),
            )
          ],
        );
      },
    );
  }

  void _marcarComoPago(Custo custo) {
    setState(() {
      custo.status = "Pago";
    });
    _salvarCustos();
  }

  List<Custo> _custosDoDia(DateTime dia) {
    return custos.where((c) {
      return c.vencimento.year == dia.year &&
          c.vencimento.month == dia.month &&
          c.vencimento.day == dia.day;
    }).toList();
  }

  Map<String, double> _resumoPorCategoria(int mes) {
    final Map<String, double> categorias = {};
    for (var c in custos.where((c) => c.vencimento.month == mes)) {
      categorias[c.categoria] = (categorias[c.categoria] ?? 0) + c.valor;
    }
    return categorias;
  }

  @override
  Widget build(BuildContext context) {
    final resumoCategoria = _resumoPorCategoria(_selectedMonth);
    final larguraTela = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Custos Mensais - Web"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _adicionarCusto,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: larguraTela > 800
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 300,
                            child: PieChart(
                              PieChartData(
                                sections: resumoCategoria.entries.map((entry) {
                                  final color = Colors.primaries[resumoCategoria.keys
                                          .toList()
                                          .indexOf(entry.key) %
                                      Colors.primaries.length];
                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value,
                                    title: resumoCategoria.values.reduce((a, b) => a + b) >
                                            0
                                        ? "${((entry.value / resumoCategoria.values.reduce((a, b) => a + b)) * 100).toStringAsFixed(1)}%"
                                        : "0%",
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold),
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _custosDoDia(_selectedDay ?? _focusedDay).length,
                            itemBuilder: (context, index) {
                              final custo = _custosDoDia(_selectedDay ?? _focusedDay)[index];
                              final vencido = custo.vencimento.isBefore(DateTime.now()) &&
                                  custo.status == "Pendente";
                              if (vencido) custo.status = "Atrasado";

                              return Card(
                                child: ListTile(
                                  title: Text(custo.titulo),
                                  subtitle: Text(
                                    "Venc: ${DateFormat('dd/MM/yyyy').format(custo.vencimento)}\nValor: R\$ ${custo.valor.toStringAsFixed(2)}
