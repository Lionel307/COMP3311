# COMP3311 21T3 Ass2 ... Python helper functions
# add here any functions to share between Python scripts 
# you must submit this even if you add nothing

def getProgram(db,code):
  cur = db.cursor()
  cur.execute("select * from Programs where code = %s",[code])
  info = cur.fetchone()
  cur.close()
  if not info:
    return None
  else:
    return info

def getStream(db,code):
  cur = db.cursor()
  cur.execute("select * from Streams where code = %s",[code])
  info = cur.fetchone()
  cur.close()
  if not info:
    return None
  else:
    return info

def getStudent(db,zid):
  cur = db.cursor()
  qry = """
  select p.*, c.name
  from   People p
         join Students s on s.id = p.id
         join Countries c on p.origin = c.id
  where  p.id = %s
  """
  cur.execute(qry,[zid])
  info = cur.fetchone()
  cur.close()
  if not info:
    return None
  else:
    return info

def getRule(db, subject, rule_names):
  foundational_comp = ['COMP1511','COMP1521','COMP1531','COMP2511','COMP2521']
  comp_math = ['MATH1081','MATH1131','MATH1141','MATH1231','MATH1241']
  cur = db.cursor()
  
  free_elective = False
  
  for name in rule_names:
    # print(name)
    if "Free Electives" in name:
      free_elective = True
    q1 = """select distinct definition
            from Academic_object_groups
            where name = %s"""
    cur.execute(q1, [name])
    x = cur.fetchone()
    
    if subject in x[0]:
      return name
    elif subject[0:5]+"###" in x[0]:
      return name
  if subject in foundational_comp:
    return "Foundational Computing"
  elif subject in comp_math:
    return "Comp Sci Maths"
  elif "GENS" in subject:
    return "General Education"
  elif free_elective:
    return "Free Electives"
  return "does not satisfy any rule"

      
def getSubjects(db, stream, program):
  cur = db.cursor()
  subjects = []

  q = """select a.name, a.defby, r.type
           from stream_rules sr 
            join Rules r on (r.id = sr.rule)
            join Streams s on (sr.stream = s.id)
            join Academic_object_groups a on (a.id = r.ao_group)
           where s.code = %s"""
  cur.execute(q, [stream])

  for t in cur.fetchall():
    academic_name = t[0]
    def_group = t[1]
    rule_type = t[2]
    q3 = """select distinct definition
                from Academic_object_groups
                where name = %s
                """
    cur.execute(q3, [academic_name])
    for s in cur.fetchall():
      courses = s[0].split(",")
      if (def_group == "enumerated" and rule_type == "CC"):
        for i in courses:

          subjects.append(i)

  q = """select a.name, a.defby, r.type
           from Rules r
           join program_rules pr on (pr.rule = r.id)
           join Programs p on (pr.program = p.id)
           join Academic_object_groups a on (a.id = r.ao_group)
           where p.code = %s
           """
  cur.execute(q, [program])

  for t in cur.fetchall():
    academic_name = t[0]
    def_group = t[1]
    rule_type = t[2]
    q3 = """select distinct definition
                from Academic_object_groups
                where name = %s
                """
    cur.execute(q3, [academic_name])
    for s in cur.fetchall():
      courses = s[0].split(",")
      if (def_group == "enumerated" and rule_type == "CC"):
        for i in courses:

          subjects.append(i)
  return subjects

def checkRemaining(db, zid, stream, program):
  cur = db.cursor()

  q = """select r.type, r.name, r.min_req, r.max_req
          from Rules r
          join stream_rules sr on (sr.rule = r.id)
          join Streams s on (sr.stream = s.id)
          where s.code = %s
          """
  cur.execute(q, [stream])
  # for each rule in the stream that is not CC 
  for rule in cur.fetchall():
    req = 0
    min_req = rule[2]
    max_req = rule[3]
    if (rule[0] != "CC"):
      # for each subject in the students transcript
      q1 = """select distinct s.code, c.grade, s.uoc
                from Course_enrolments c 
                Join Courses d on (c.course = d.id)
                Join Subjects s on (d.subject = s.id)
                where c.student = %s
                """
      cur.execute(q1, [zid])
      for t in cur.fetchall():
          fail = ['AF','FL','UF']
          uoc_list = ['A', 'B', 'C', 'D', 'HD', 'DN', 'CR', 'PS', 'XE', 'T', 'SY', 'EC', 'NC']
          course_code = t[0]
          grade = t[1]
          uoc = t[2]
          q3 = """select distinct definition
                      from Academic_object_groups
                      where name = %s
                      """
          cur.execute(q3, [rule[1]])
          for s in cur.fetchall():
            courses = s[0].split(",")

            if grade not in fail and grade in uoc_list:
              if course_code in courses:
                req += uoc

      if max_req is not None and min_req is not None:
        min_req -= req
        max_req -= req
        if max_req > 0:
          print(f"between {min_req} and {max_req} UOC courses from {rule[1]}")
      elif min_req is not None:
        min_req -= req
        if min_req > 0:
          print(f"at least {min_req} UOC courses from {rule[1]}")
      elif max_req is not None:
        max_req -= req
        if max_req > 0:
          print(f"up to {max_req} UOC courses from {rule[1]}")

  q = """select r.type, r.name, r.min_req, r.max_req
            from Rules r
            join program_rules pr on (pr.rule = r.id)
            join Programs p on (pr.program = p.id)
            where p.code = %s
            """
  cur.execute(q, [program])
  # for each rule in the stream that is not CC 
  for rule in cur.fetchall():
    req = 0
    
    if (rule[0] != "CC"):
      min_req = rule[2]
      max_req = rule[3]
      # for each subject in the students transcript
      q1 = """select distinct s.code, c.grade, s.uoc
                from Course_enrolments c 
                Join Courses d on (c.course = d.id)
                Join Subjects s on (d.subject = s.id)
                where c.student = %s
                """
      cur.execute(q1, [zid])
      for t in cur.fetchall():
          fail = ['AF','FL','UF']
          uoc_list = ['A', 'B', 'C', 'D', 'HD', 'DN', 'CR', 'PS', 'XE', 'T', 'SY', 'EC', 'NC']
          course_code = t[0]
          grade = t[1]
          uoc = t[2]
          
          q3 = """select distinct definition
                      from Academic_object_groups
                      where name = %s
                      """
          cur.execute(q3, [rule[1]])
          for s in cur.fetchall():
            courses = s[0].split(",")
            if course_code in courses and grade not in fail and grade in uoc_list:
              req += uoc
      if rule[0] != "DS":
        if max_req is not None and min_req is not None:
          min_req -= req
          max_req -= req
          if min_req == max_req and min_req > 0 and max_req > 0:
            print(f"{min_req} UOC of {rule[1]}")
          elif max_req > 0:
            print(f"between {min_req} and {max_req} UOC courses from {rule[1]}")
        elif min_req is not None:
          min_req -= req
          if min_req > 0:
            print(f"at least {min_req} UOC courses from {rule[1]}")
        elif max_req is not None:
          max_req -= req
          if max_req > 0:
            print(f"up to {max_req} UOC courses from {rule[1]}")