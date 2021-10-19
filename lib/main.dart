import 'dart:developer';
import 'dart:math' hide log;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetX<HomeController>(
        init: HomeController(),
        builder: (controller) {
          if (controller.isLoading.value) return const LinearProgressIndicator();
          if (controller.isSearch.value) {
            return Scaffold(
              appBar: AppBar(
                actions: [
                  IconButton(
                      onPressed: () {
                        controller.isSearch.value = false;
                        controller.klinik(Model());
                      },
                      icon: const Icon(Icons.list)),
                ],
              ),
              body: ListTile(
                title: Text(controller.klinik.value.name),
                subtitle: Text(controller.klinik.value.address),
                leading: IconButton(
                  onPressed: () async {
                    try {
                      final url =
                          'https://www.google.com/maps/search/?api=1&query=${controller.klinik.value.latitude},${controller.klinik.value.longitude}';
                      if (await canLaunch(url)) {
                        await launch(url);
                        return;
                      }
                    } catch (e) {
                      log(e.toString());
                      return;
                    }
                  },
                  icon: const Icon(Icons.location_pin),
                ),
                trailing: IconButton(
                  onPressed: () async {
                    try {
                      final url = controller.klinik.value.phoneNumber;
                      log(url);
                      if (await canLaunch(url)) {
                        await launch(url);
                        return;
                      }
                    } catch (e) {
                      log(e.toString());
                      return;
                    }
                  },
                  icon: const Icon(Icons.call),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(onPressed: controller.astar, icon: const Icon(Icons.search)),
              ],
            ),
            body: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: RefreshIndicator(
                child: ListView.separated(
                  itemBuilder: (context, index) => ListTile(
                    title: Text(controller.listKlinik[index].name),
                    subtitle: Text(controller.listKlinik[index].address),
                    leading: IconButton(
                      onPressed: () async {
                        try {
                          final url =
                              'https://www.google.com/maps/search/?api=1&query=${controller.listKlinik[index].latitude},${controller.listKlinik[index].longitude}';
                          if (await canLaunch(url)) {
                            await launch(url);
                            return;
                          }
                        } catch (e) {
                          log(e.toString());
                          return;
                        }
                      },
                      icon: const Icon(Icons.location_pin),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        try {
                          final url = controller.listKlinik[index].phoneNumber;
                          log(url);
                          if (await canLaunch(url)) {
                            await launch(url);
                            return;
                          }
                        } catch (e) {
                          log(e.toString());
                          return;
                        }
                      },
                      icon: const Icon(Icons.call),
                    ),
                  ),
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: controller.listKlinik.length,
                ),
                onRefresh: () async => controller.getData(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeController extends GetxController {
  final Rx<LocationData> location = LocationData.fromMap({
    'latitude': -5.1401055397399835,
    'longitude': 119.48312381257085,
  }).obs;
  final RxBool isLoading = false.obs;
  final FirebaseFirestore _store = FirebaseFirestore.instance;
  final RxList<Model> listKlinik = <Model>[].obs;
  final Rx<Model> klinik = Model().obs;
  final RxBool isSearch = false.obs;

  @override
  void onInit() {
    super.onInit();
    location.bindStream(Location.instance.onLocationChanged);
    getData();
  }

  void getData() async {
    try {
      isLoading.value = true;
      final result = await _store.collection('klinik').get();
      listKlinik.assignAll(result.docs.map((e) => Model.fromJson(e.data())).toList());
      return;
    } catch (e) {
      log(e.toString());
      return;
    } finally {
      isLoading.value = false;
    }
  }

  void astar() {
    klinik(listKlinik.map(
      (element) {
        //tentukan nilai x dan y
        final x1 = location.value.latitude!;
        final y1 = location.value.longitude!;
        final x2 = element.latitude;
        final y2 = element.longitude;

        //cari h'n
        final hn = sqrt((pow(x2 - x1, 2) + pow(y2 - y1, 2)));
        final point = Geoflutterfire();
        final p = point.point(latitude: x1, longitude: y1);
        //cari gn
        final gn = p.distance(lat: x2, lng: y2);

        //cari fn
        final fn = hn + gn;
        return Model(
          address: element.address,
          createdAt: element.createdAt,
          jarak: fn,
          latitude: element.latitude,
          longitude: element.longitude,
          name: element.name,
          phoneNumber: element.phoneNumber,
          updatedAt: element.updatedAt,
        );
      },
    ).reduce((value, element) => value.jarak < element.jarak ? value : element));
    isSearch.value = true;
  }
}

class Model {
  final String address;
  final int createdAt;
  final double latitude;
  final double longitude;
  final String name;
  final String phoneNumber;
  final int updatedAt;
  final double jarak;

  Model({
    this.address = '',
    this.createdAt = 0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.name = '',
    this.phoneNumber = '',
    this.updatedAt = 0,
    this.jarak = 0.0,
  });

  factory Model.fromJson(Map<String, dynamic> json) => Model(
        address: json['address'],
        createdAt: json['createdAt'],
        latitude: double.parse(json['latitude']),
        longitude: double.parse(json['longitude']),
        name: json['name'],
        phoneNumber: json['phoneNumber'],
        updatedAt: json['updatedAt'],
      );
}
