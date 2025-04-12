using System.Collections.Generic;
using UnityEngine;

public class SeismicSense : MonoBehaviour
{
    
    public Shader seismicShader;

    public Material seismicMaterial;
    [Header("Global Settings")]
    public bool transparent = false;
    public bool displacement = false;
    [Range(0.1f, 20f)]
    public float waveTimeLimit = 10f;
    [Range(0.01f, 50f)]
    [Header("Per Wave Settings")]
    public float waveRange = 10f;
    [Range(0.001f, 1f)]
    public float waveWidth = 0.07f;
    public Color waveColor = Color.gray;
    public float waveHeight = 1f;


    private List<float> _timer;
    private List<float> _ranges;
    private List<float> _widths;
    private List<float> _heights;
    private List<Vector4> _colors;
    private List<Vector4> _seismicCenter;
    private int _active = 0;
    private int _maxWaves = 20;

    void OnEnable()
    {
        _timer = new List<float>();
        _ranges = new List<float>();
        _widths = new List<float>();
        _heights = new List<float>();
        _seismicCenter = new List<Vector4>();
        _colors = new List<Vector4>();

        for(int i = 0; i < _maxWaves; i++)
        {
            _seismicCenter.Add(Vector4.zero);
            _timer.Add(0.0f);
            _ranges.Add(waveRange);
            _widths.Add(waveWidth);
            _heights.Add(waveHeight);
            _colors.Add(waveColor);
        }
        
        seismicMaterial.SetInt("_Active", _active);
        seismicMaterial.SetFloatArray("_Timer", _timer);
        seismicMaterial.SetVectorArray("_SeismicCenter", _seismicCenter);
    }

    void Update()
    {
        if(Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hitInfo;
            if(Physics.Raycast(ray, out hitInfo))
            {
                AddWave(hitInfo.point);
            }
        }

        UpdateWaves();
    }

    public void AddWave(Vector3 point)
    {
        _seismicCenter.RemoveAt(_maxWaves - 1);
        _timer.RemoveAt(_maxWaves - 1);
        _ranges.RemoveAt(_maxWaves - 1);
        _widths.RemoveAt(_maxWaves - 1);
        _heights.RemoveAt(_maxWaves - 1);
        _colors.RemoveAt(_maxWaves - 1);

        _seismicCenter.Insert(0, new Vector4(point.x, point.y, point.z, 1.0f));
        _colors.Insert(0, waveColor);
        _timer.Insert(0, 0.0f);
        _ranges.Insert(0, waveRange);
        _widths.Insert(0, waveWidth);
        _heights.Insert(0, waveHeight);
        if(_active < _maxWaves) _active++;
    }

    void UpdateWaves()
    {
        for(int i = 0; i < _timer.Count; i++)
        {
            _timer[i] += Time.deltaTime;
        }

        if(_active > 0 && _timer[_active - 1] > waveTimeLimit)
        {
            _active--;
        }

        seismicMaterial.SetInt("_Active", _active);
        if(_active > 0)
        {
            seismicMaterial.SetFloat("_TimeLimit",waveTimeLimit);
            seismicMaterial.SetFloatArray("_Range",_ranges);
            seismicMaterial.SetFloatArray("_Width",_widths);
            seismicMaterial.SetFloatArray("_Height",_heights);
            seismicMaterial.SetFloatArray("_Timer", _timer);
            seismicMaterial.SetVectorArray("_SeismicCenter", _seismicCenter);
            seismicMaterial.SetVectorArray("_WaveColor", _colors);
        }
    }

    void OnValidate()
    {
        if(transparent) seismicMaterial.EnableKeyword("SEISMIC_TRANSPARENT");
        else seismicMaterial.DisableKeyword("SEISMIC_TRANSPARENT");
        
        if(displacement) seismicMaterial.EnableKeyword("SEISMIC_DISPLACEMENT");
        else seismicMaterial.DisableKeyword("SEISMIC_DISPLACEMENT");
    }

    void OnDisable()
    {
        _timer = null;
        _seismicCenter = null;
    }

}
