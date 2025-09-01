
class Drug {
  final String id;
  final String name;
  final int basePrice;
  final int volMin;
  final int volMax;
  final double rarity;
  Drug({required this.id, required this.name, required this.basePrice, required this.volMin, required this.volMax, required this.rarity});
  factory Drug.fromJson(Map<String, dynamic> json) => Drug(
    id: json['id'],
    name: json['name'],
    basePrice: json['basePrice'],
    volMin: json['volMin'],
    volMax: json['volMax'],
    rarity: (json['rarity'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'basePrice': basePrice,
    'volMin': volMin,
    'volMax': volMax,
    'rarity': rarity,
  };
}

class Offer {
  final String drugId;
  final int qty;
  final int priceOffer;
  final String customerType;
  final double risk;
  Offer({required this.drugId, required this.qty, required this.priceOffer, required this.customerType, required this.risk});
  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    drugId: json['drugId'],
    qty: json['qty'],
    priceOffer: json['priceOffer'],
    customerType: json['customerType'],
    risk: (json['risk'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'drugId': drugId,
    'qty': qty,
    'priceOffer': priceOffer,
    'customerType': customerType,
    'risk': risk,
  };
}

class District {
  final String id;
  final String name;
  final int wealth;
  final double policePresence;
  final double prosperity;
  final String? factionId; // controlling faction
  District({required this.id, required this.name, required this.wealth, required this.policePresence, required this.prosperity, this.factionId});
  factory District.fromJson(Map<String, dynamic> json) => District(
    id: json['id'],
    name: json['name'],
    wealth: json['wealth'],
    policePresence: (json['policePresence'] as num).toDouble(),
    prosperity: (json['prosperity'] as num).toDouble(),
    factionId: json['factionId'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'wealth': wealth,
    'policePresence': policePresence,
    'prosperity': prosperity,
    if (factionId != null) 'factionId': factionId,
  };
  District copyWith({String? factionId}) => District(
    id: id,
    name: name,
    wealth: wealth,
    policePresence: policePresence,
    prosperity: prosperity,
    factionId: factionId ?? this.factionId,
  );
}

class Edge {
  final String from;
  final String to;
  final bool blocked;
  Edge({required this.from, required this.to, required this.blocked});
  factory Edge.fromJson(Map<String, dynamic> json) => Edge(
    from: json['from'],
    to: json['to'],
    blocked: json['blocked'],
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'blocked': blocked,
  };
}

class Event {
  final String type;
  final String districtId;
  final String desc;
  final String? drugId; // optional, used for scarcity/boon events
  Event({required this.type, required this.districtId, required this.desc, this.drugId});
  factory Event.fromJson(Map<String, dynamic> json) => Event(
    type: json['type'],
    districtId: json['districtId'],
    desc: json['desc'],
    drugId: json['drugId'],
  );
  Map<String, dynamic> toJson() => {
    'type': type,
    'districtId': districtId,
    'desc': desc,
    if (drugId != null) 'drugId': drugId,
  };
}

class Upgrades {
  final int vehicle;
  final int safehouse;
  final int burner;
  final int scanner;
  final int laundromat;
  Upgrades({this.vehicle = 0, this.safehouse = 0, this.burner = 0, this.scanner = 0, this.laundromat = 0});
  factory Upgrades.fromJson(Map<String, dynamic> json) => Upgrades(
    vehicle: json['vehicle'] ?? 0,
    safehouse: json['safehouse'] ?? 0,
    burner: json['burner'] ?? 0,
    scanner: json['scanner'] ?? 0,
    laundromat: json['laundromat'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'vehicle': vehicle,
    'safehouse': safehouse,
    'burner': burner,
    'scanner': scanner,
    'laundromat': laundromat,
  };
}

class Inventory {
  final Map<String, int> drugs;
  Inventory({required this.drugs});
  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
    drugs: Map<String, int>.from(json['drugs'] ?? {}),
  );
  Map<String, dynamic> toJson() => {
    'drugs': drugs,
  };
}

class Supplier {
  final String id;
  final String name;
  final double trust; // 0..1
  final double quality; // 0..1
  final double priceMod; // e.g., 0.9 = 10% cheaper
  final bool contracted;
  final int? minDaily; // optional SLA
  final int? contractedUntilDay; // optional expiry day index
  Supplier({required this.id, required this.name, required this.trust, required this.quality, required this.priceMod, this.contracted = false, this.minDaily, this.contractedUntilDay});
  Supplier copyWith({bool? contracted, int? minDaily, int? contractedUntilDay}) => Supplier(
    id: id,
    name: name,
    trust: trust,
    quality: quality,
    priceMod: priceMod,
    contracted: contracted ?? this.contracted,
    minDaily: minDaily ?? this.minDaily,
    contractedUntilDay: contractedUntilDay ?? this.contractedUntilDay,
  );
  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'],
    name: json['name'],
    trust: (json['trust'] as num).toDouble(),
    quality: (json['quality'] as num).toDouble(),
    priceMod: (json['priceMod'] as num).toDouble(),
    contracted: json['contracted'] ?? false,
    minDaily: json['minDaily'],
    contractedUntilDay: json['contractedUntilDay'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trust': trust,
    'quality': quality,
    'priceMod': priceMod,
    'contracted': contracted,
    if (minDaily != null) 'minDaily': minDaily,
    if (contractedUntilDay != null) 'contractedUntilDay': contractedUntilDay,
  };
}

class CrewMember {
  final String id;
  final String role; // Chemist, Driver, Fixer, Lawyer
  final int skill; // 1..5
  final int wage; // per day
  final int fatigue; // 0..100 for today
  final int morale; // 0..100
  // New fields for autonomous ops
  final String? assignedDistrictId; // where they operate; null => current district
  final String strategy; // 'greedy' | 'balanced' | 'lowrisk'
  final String status; // 'idle' | 'selling' | 'resting' | 'arrested'
  final int arrestedDays; // days remaining if arrested
  final int lifetimeEarned; // total revenue credited to bank
  final int todayEarned; // last day contribution
  CrewMember({required this.id, required this.role, required this.skill, required this.wage, this.fatigue = 0, this.morale = 70, this.assignedDistrictId, this.strategy = 'balanced', this.status = 'idle', this.arrestedDays = 0, this.lifetimeEarned = 0, this.todayEarned = 0});
  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
    id: json['id'],
    role: json['role'],
    skill: json['skill'],
    wage: json['wage'],
    fatigue: json['fatigue'] ?? 0,
    morale: json['morale'] ?? 70,
    assignedDistrictId: json['assignedDistrictId'],
    strategy: json['strategy'] ?? 'balanced',
    status: json['status'] ?? 'idle',
    arrestedDays: json['arrestedDays'] ?? 0,
    lifetimeEarned: json['lifetimeEarned'] ?? 0,
    todayEarned: json['todayEarned'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'skill': skill,
    'wage': wage,
    'fatigue': fatigue,
    'morale': morale,
    if (assignedDistrictId != null) 'assignedDistrictId': assignedDistrictId,
    'strategy': strategy,
    'status': status,
    'arrestedDays': arrestedDays,
    'lifetimeEarned': lifetimeEarned,
    'todayEarned': todayEarned,
  };
}

class Faction {
  final String id;
  final String name;
  final int reputation; // -100..100
  Faction({required this.id, required this.name, required this.reputation});
  Faction copyWith({int? reputation}) => Faction(id: id, name: name, reputation: reputation ?? this.reputation);
  factory Faction.fromJson(Map<String, dynamic> json) => Faction(
    id: json['id'],
    name: json['name'],
    reputation: json['reputation'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'reputation': reputation,
  };
}

// Lightweight legal case model for arrests/trials.
class LegalCase {
  final String id;
  final String type; // 'crew' | 'player'
  final String? crewId; // if type == 'crew'
  final int severity; // 1..3
  final int bail; // cost to bail out (if allowed)
  final int daysUntilHearing; // countdown until resolution
  final String status; // 'open' | 'bailed' | 'resolved'
  final int fineOnConviction;
  final int jailDaysOnConviction;
  LegalCase({
    required this.id,
    required this.type,
    this.crewId,
    required this.severity,
    required this.bail,
    required this.daysUntilHearing,
    this.status = 'open',
    this.fineOnConviction = 100,
    this.jailDaysOnConviction = 2,
  });
  factory LegalCase.fromJson(Map<String, dynamic> json) => LegalCase(
        id: json['id'],
        type: json['type'],
        crewId: json['crewId'],
        severity: json['severity'] ?? 1,
        bail: json['bail'] ?? 0,
        daysUntilHearing: json['daysUntilHearing'] ?? 1,
        status: json['status'] ?? 'open',
        fineOnConviction: json['fineOnConviction'] ?? 100,
        jailDaysOnConviction: json['jailDaysOnConviction'] ?? 2,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (crewId != null) 'crewId': crewId,
        'severity': severity,
        'bail': bail,
        'daysUntilHearing': daysUntilHearing,
        'status': status,
        'fineOnConviction': fineOnConviction,
        'jailDaysOnConviction': jailDaysOnConviction,
      };
}
